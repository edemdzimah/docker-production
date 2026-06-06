# Docker in Production — Assignment 2

## What is this project?

This is Assignment 2 is an amazing production - docker in production. We took the Flask app from Assignment 1 and made it production-ready. That means smaller images, automated pipelines, security scanning, proper secrets handling, and live monitoring.

## How to start everything

```bash
docker compose up --build -d
```

That one command starts all 5 services — the Flask app, Redis, Postgres, Prometheus, and Grafana. Everything talks to each other automatically.

## The image is on GHCR

Every time I push code to GitHub, the pipeline builds and uploads the image automatically. No manual terminal commands needed.

```
ghcr.io/edemdzimah/docker-production:latest
ghcr.io/edemdzimah/docker-production:sha-0dc9e50
```

## Part 1 — I made the image smaller with multi-stage builds

Before this assignment, the Dockerfile built everything in one go — Python, pip, all the build tools — and baked it all into the final image. That's wasteful and risky.

I split it into two stages. Stage 1 installs all the dependencies. Stage 2 copies only what's needed to actually run the app. No pip, no build tools in the final image.

| Image | Size |
|-------|------|
| v1.0 (Assignment 1 — single stage) | 240 MB |
| v2.0 (Assignment 2 — multi-stage) | 234 MB |

The app also runs as a non-root user now (`appuser`) which is the right way to do it in production.

## Part 2 — GitHub Actions does the boring stuff for me

I set up a CI/CD pipeline in `.github/workflows/docker-publish.yml`.

Whenever I push to main, GitHub spins up a fresh Ubuntu machine, builds my Docker image, and pushes it to GHCR with two tags — `latest` and a unique SHA tag so every build is traceable. I don't touch a terminal for any of it.

The secret (my GitHub token) is stored safely in GitHub Secrets — never in the code.

## Part 3 — Security scanning with Trivy

I used Trivy to scan my images for known vulnerabilities. Here's honestly what happened:

My first scan on `flask-app:v2.0` found some HIGH and CRITICAL vulnerabilities in system libraries inside the base image — stuff like `libgnutls30` and `libsqlite3`. These are not in my code, they come bundled with `python:3.11-slim`.

I tried fixing it by switching to `python:3.11-slim-bookworm` and rebuilding as `flask-app:v2.1`. The result was actually more vulnerabilities — 16 total (10 HIGH, 6 CRITICAL).

That surprised me at first but it makes sense — the newer image exposed more CVEs that the Trivy database now knows about. In a real job, the next step would be to apply OS-level package upgrades inside the Dockerfile or wait for the base image maintainers to patch them. The vulnerabilities are all in system-level libraries, not in my Flask app or Python packages.

## Part 4 — No hardcoded secrets

In Assignment 1 the database password was sitting in `docker-compose.yml` in plain text. That's bad — anyone who sees the repo sees the password.

Now all the sensitive stuff lives in a `.env` file that never gets committed to GitHub. I added it to `.gitignore`. There's a `.env.example` file in the repo instead so teammates know what variables they need without seeing the actual values.

## Part 5 — Live monitoring with Prometheus and Grafana

This was the most satisfying part. I added `prometheus-flask-exporter` to the Flask app. It automatically creates a `/metrics` endpoint that lists everything happening in the app — total requests, response times, memory usage.

Prometheus scrapes that endpoint every 15 seconds and stores the data. Grafana reads from Prometheus and turns it into graphs.

I built a dashboard called Flask App Production Dashboard that shows `flask_http_request_total` — the number of HTTP requests hitting the app in real time. Watching the graph climb as I curled the endpoint made the whole concept of production monitoring click for me.

To see it yourself:
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (login: admin / admin)

## Screenshots

| File | What it shows |
|------|--------------|
| `part1-multistage.png` | Both image sizes side by side |
| `part2-actions.png` | GitHub Actions pipeline — all steps green |
| `part2-ghcr.png` | GHCR showing the image with latest and sha tags |
| `part3-scan-before.png` | Trivy scan on v2.0 |
| `part3-scan-after.png` | Trivy scan on v2.1 after base image change |
| `part4-compose.png` | All services healthy |
| `part4-gitignore.png` | .gitignore showing .env is excluded |
| `part5-stack.png` | All 5 services running |
| `part5-grafana.png` | Live Grafana dashboard with Flask metrics |

## Reflection

The hardest part was honestly wrapping my head around how containers talk to each other inside Docker's network. When I set up Grafana to connect to Prometheus, my first instinct was to use `http://localhost:9090`. That doesn't work. Inside Docker, containers find each other by service name — so it's `http://prometheus:9090`. Once that clicked, everything made sense.

The biggest thing I learned from this whole assignment is that getting an app to run is actually the easy part. Getting it to run safely, automatically, and in a way where you can see what's happening — that's the real work. I went from just running containers to thinking about security, automation, and observability. That feels like a real shift.
