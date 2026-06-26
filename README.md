# Safara — Your Smart Kenya Travel Companion

Safara is an AI-powered travel assistant for Kenya, built as a local-first RAG application using **Ollama**, **Chroma**, and **LangChain4j** — no cloud API keys required.

## Architecture

- **Backend**: Java 21 + Spring Boot 3.3 + LangChain4j (RAG with query compression)
- **Frontend**: Flutter (Material 3) with streaming chat and document upload
- **LLM**: Ollama (`llama3.2`)
- **Embeddings**: Local ONNX `all-MiniLM-L6-v2` (HuggingFace model, in-process)
- **Vector DB**: Chroma (Docker)

```
safara/
├── backend/          # Spring Boot API
├── frontend/         # Flutter mobile app
├── docker-compose.yml
└── README.md
```

## Prerequisites

| Tool | Version |
|------|---------|
| Java | **21+** (required — Java 17 will not work) |
| Maven | Not required — use included `mvnw.cmd` wrapper |
| Flutter | Latest stable |
| Docker | For Chroma |
| Ollama | [ollama.com](https://ollama.com) |

## Quick Start

### 1. Start Chroma

```bash
docker compose up -d
# Or manually (must use 0.5.x — latest Chroma is API v2-only):
docker run -d -p 8000:8000 --name safara-chroma chromadb/chroma:0.5.23
```

### 2. Start Ollama and pull the model

```bash
ollama pull llama3.2
ollama serve   # if not already running
```

### 3. Run the backend

No global Maven install needed. From the `backend` folder:

```powershell
# Set Java 21 (adjust path if needed)
$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-21.0.11.10-hotspot"

# Run with the Maven Wrapper (downloads Maven automatically on first run)
.\mvnw.cmd spring-boot:run
```

If `JAVA_HOME` is not set, install JDK 21:

```powershell
winget install Microsoft.OpenJDK.21
```

Then open a **new terminal** and run `.\mvnw.cmd spring-boot:run` again.

The API starts at **http://localhost:8080**. On first launch, sample Kenya tourism `.txt` files are auto-ingested from `backend/data/samples/`.

### 4. Run the Flutter app

```bash
cd frontend
flutter pub get
flutter run
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/chat` | Streaming chat (SSE). Body: `{ "sessionId": "uuid", "message": "..." }` |
| `POST` | `/api/ingest` | Upload PDF/TXT files (`files` multipart field) |
| `GET` | `/api/documents` | List ingested documents |

### SSE event types (`POST /api/chat`)

| Event | Payload |
|-------|---------|
| `sources` | JSON array of `{ fileName, excerpt, score }` |
| `token` | Text chunk from the LLM |
| `done` | Stream complete |
| `error` | Error message |

## Configuration

Edit [`backend/src/main/resources/application.yml`](backend/src/main/resources/application.yml):

```yaml
langchain4j:
  ollama:
    base-url: http://localhost:11434
    chat-model:
      model-name: llama3.2   # change to any Ollama model

safara:
  chroma:
    base-url: http://localhost:8000
  rag:
    max-results: 5
    min-score: 0.65
```

## Mobile / Emulator Networking

| Platform | Backend URL |
|----------|-------------|
| Android Emulator | `http://10.0.2.2:8080` (default in app) |
| iOS Simulator | `http://localhost:8080` |
| Physical device | Your machine's LAN IP, e.g. `http://192.168.1.10:8080` |

To use a custom URL, change `ApiConfig.defaultBaseUrl` in [`frontend/lib/services/api_service.dart`](frontend/lib/services/api_service.dart).

## Sample cURL

```bash
# List documents
curl http://localhost:8080/api/documents

# Upload a document
curl -X POST http://localhost:8080/api/ingest \
  -F "files=@backend/data/samples/kenya-safaris.txt"

# Stream chat (SSE)
curl -N -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d '{"sessionId":"test-session","message":"When is the best time to visit Maasai Mara?"}'
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `Chroma not reachable` | Run `docker compose up -d` and verify `curl http://localhost:8000/api/v1/heartbeat` |
| `status code: 405` on startup (Chroma) | You likely have the latest Chroma image (v2-only). Run `docker compose down` then `docker compose up -d` to use the pinned `0.5.23` image |
| `Ollama not reachable` | Ensure Ollama is running; run `ollama pull llama3.2` |
| Flutter can't connect (Android) | Use `10.0.2.2` not `localhost` |
| Flutter can't connect (physical phone) | Use your PC's LAN IP; allow port 8080 in firewall |
| Empty / generic answers | Upload tourism docs via **Manage Documents** or check sample seed in `backend/data/samples/` |
| Slow first response | ONNX embedding model loads on first request (~few seconds) |
| `mvn` not recognized | Use `.\mvnw.cmd` instead of `mvn` (included in `backend/`) |
| Java version error | Safara requires **Java 21**. Run `java -version` — if it shows 17, set `JAVA_HOME` to JDK 21 |

## Features

- RAG-powered chat grounded in uploaded documents
- Advanced RAG with `CompressingQueryTransformer` + `DefaultRetrievalAugmentor`
- Streaming responses with source citations
- Per-session chat memory (server-side)
- PDF + TXT document ingestion
- Material 3 UI with dark/light theme

## License

MIT
