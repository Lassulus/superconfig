"""Custom exceptions for browser-cli."""


class BrowserCLIError(Exception):
    """Base exception for browser-cli errors."""


class BrowserConnectionError(BrowserCLIError):
    """Raised when unable to connect to the browser extension or server."""


class CommandError(BrowserCLIError):
    """Raised when a command fails to execute."""
