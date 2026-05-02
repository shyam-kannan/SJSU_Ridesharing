from fastapi import FastAPI


app = FastAPI(title="Safety Service", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {
        "status": "success",
        "service": "safety-service",
        "message": "Safety service placeholder is running",
    }


@app.get("/")
def root() -> dict[str, str]:
    return {
        "status": "success",
        "message": "Safety service placeholder API",
    }