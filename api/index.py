from backend.app.main import app as corestream_app


class ApiPrefixMiddleware:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] in {"http", "websocket"}:
            path = scope.get("path", "")
            if path == "/api" or path.startswith("/api/"):
                scope = dict(scope)
                scope["root_path"] = "/api"
                scope["path"] = path[4:] or "/"
                raw_path = scope.get("raw_path")
                if isinstance(raw_path, bytes) and raw_path.startswith(b"/api"):
                    scope["raw_path"] = raw_path[4:] or b"/"
        await self.app(scope, receive, send)


corestream_app.add_middleware(ApiPrefixMiddleware)
app = corestream_app
