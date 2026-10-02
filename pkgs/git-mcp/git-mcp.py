#!/usr/bin/env python3
"""
Git MCP Server - Advanced Git operations for AI assistants
"""

import asyncio
from typing import Dict, List, Any
import os

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent


class GitMCP:
    def __init__(self):
        self.repo_path = os.getcwd()

    async def run_git_command(self, cmd: List[str]) -> Dict[str, Any]:
        """Run a git command and return the result"""
        try:
            result = await asyncio.create_subprocess_exec(
                "git",
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=self.repo_path,
            )
            stdout, stderr = await result.communicate()

            if result.returncode == 0:
                return {"output": stdout.decode("utf-8")}
            else:
                return {"error": stderr.decode("utf-8")}
        except Exception as e:
            return {"error": str(e)}

    async def git_status(self, args: Dict[str, Any]) -> str:
        """Get detailed git status"""
        cmd = ["status", "--porcelain"]
        if args.get("untracked", True):
            cmd.append("--untracked-files=all")
        if args.get("ignored"):
            cmd.append("--ignored")

        result = await self.run_git_command(cmd)
        if "error" in result:
            return f"Error: {result['error']}"

        return result["output"]

    async def git_diff(self, args: Dict[str, Any]) -> str:
        """Get diff with various options"""
        cmd = ["diff"]
        if args.get("staged"):
            cmd.append("--staged")
        if args.get("commit"):
            cmd.append(args["commit"])
        if args.get("context"):
            cmd.extend(["-U", str(args["context"])])
        if args.get("files"):
            cmd.extend(["--"] + args["files"])

        result = await self.run_git_command(cmd)
        if "error" in result:
            return f"Error: {result['error']}"

        return result["output"]

    async def git_log(self, args: Dict[str, Any]) -> str:
        """Get commit history"""
        cmd = ["log", "--oneline"]
        if args.get("limit"):
            cmd.extend(["-n", str(args["limit"])])
        if args.get("author"):
            cmd.extend(["--author", args["author"]])
        if args.get("since"):
            cmd.extend(["--since", args["since"]])
        if args.get("grep"):
            cmd.extend(["--grep", args["grep"]])
        if args.get("files"):
            cmd.extend(["--"] + args["files"])

        result = await self.run_git_command(cmd)
        if "error" in result:
            return f"Error: {result['error']}"

        return result["output"]

    async def git_branch(self, args: Dict[str, Any]) -> str:
        """Manage branches"""
        action = args.get("action", "list")

        if action == "list":
            cmd = ["branch", "-v"]
            if args.get("remote"):
                cmd.append("-r")
        elif action == "create":
            if not args.get("name"):
                return "Error: Branch name required"
            cmd = ["checkout", "-b", args["name"]]
        elif action == "delete":
            if not args.get("name"):
                return "Error: Branch name required"
            cmd = ["branch", "-d", args["name"]]
        else:
            return f"Error: Unknown action: {action}"

        result = await self.run_git_command(cmd)
        if "error" in result:
            return f"Error: {result['error']}"

        return result["output"]

    async def git_add(self, args: Dict[str, Any]) -> str:
        """Stage files"""
        files = args.get("files", [])
        if not files:
            return "Error: No files specified"

        cmd = ["add"] + files
        result = await self.run_git_command(cmd)
        if "error" in result:
            return f"Error: {result['error']}"

        return "Files staged successfully"

    async def git_commit(self, args: Dict[str, Any]) -> str:
        """Create a commit"""
        message = args.get("message")
        if not message:
            return "Error: Commit message required"

        cmd = ["commit", "-m", message]
        result = await self.run_git_command(cmd)
        if "error" in result:
            return f"Error: {result['error']}"

        return result["output"]

    async def git_push(self, args: Dict[str, Any]) -> str:
        """Push commits"""
        cmd = ["push"]
        if args.get("remote"):
            cmd.append(args["remote"])
        if args.get("branch"):
            cmd.append(args["branch"])

        result = await self.run_git_command(cmd)
        if "error" in result:
            return f"Error: {result['error']}"

        return result["output"]

    async def git_pull(self, args: Dict[str, Any]) -> str:
        """Pull commits"""
        cmd = ["pull"]
        if args.get("remote"):
            cmd.append(args["remote"])
        if args.get("branch"):
            cmd.append(args["branch"])

        result = await self.run_git_command(cmd)
        if "error" in result:
            return f"Error: {result['error']}"

        return result["output"]


async def main():
    git_mcp = GitMCP()

    # Create the MCP server
    server = Server("git-mcp")

    # Register tools
    @server.list_tools()
    async def list_tools() -> List[Tool]:
        return [
            Tool(
                name="git_status",
                description="Get git repository status",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "untracked": {
                            "type": "boolean",
                            "description": "Include untracked files",
                        },
                        "ignored": {
                            "type": "boolean",
                            "description": "Include ignored files",
                        },
                    },
                    "additionalProperties": False,
                },
            ),
            Tool(
                name="git_diff",
                description="Get git diff",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "staged": {
                            "type": "boolean",
                            "description": "Show staged changes",
                        },
                        "commit": {
                            "type": "string",
                            "description": "Show diff for specific commit",
                        },
                        "files": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Specific files to diff",
                        },
                        "context": {
                            "type": "number",
                            "description": "Lines of context",
                        },
                    },
                    "additionalProperties": False,
                },
            ),
            Tool(
                name="git_log",
                description="Get commit history",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "limit": {"type": "number", "description": "Number of commits"},
                        "author": {"type": "string", "description": "Filter by author"},
                        "since": {"type": "string", "description": "Since date"},
                        "grep": {
                            "type": "string",
                            "description": "Search commit messages",
                        },
                        "files": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Show commits affecting files",
                        },
                    },
                    "additionalProperties": False,
                },
            ),
            Tool(
                name="git_branch",
                description="Manage branches",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "action": {
                            "type": "string",
                            "enum": ["list", "create", "delete"],
                            "description": "Action to perform",
                        },
                        "name": {"type": "string", "description": "Branch name"},
                        "remote": {
                            "type": "boolean",
                            "description": "Include remote branches",
                        },
                    },
                    "additionalProperties": False,
                },
            ),
            Tool(
                name="git_add",
                description="Stage files for commit",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "files": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Files to stage",
                        }
                    },
                    "required": ["files"],
                    "additionalProperties": False,
                },
            ),
            Tool(
                name="git_commit",
                description="Create a commit",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "message": {"type": "string", "description": "Commit message"}
                    },
                    "required": ["message"],
                    "additionalProperties": False,
                },
            ),
            Tool(
                name="git_push",
                description="Push commits to remote",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "remote": {"type": "string", "description": "Remote name"},
                        "branch": {"type": "string", "description": "Branch name"},
                    },
                    "additionalProperties": False,
                },
            ),
            Tool(
                name="git_pull",
                description="Pull commits from remote",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "remote": {"type": "string", "description": "Remote name"},
                        "branch": {"type": "string", "description": "Branch name"},
                    },
                    "additionalProperties": False,
                },
            ),
        ]

    @server.call_tool()
    async def call_tool(name: str, arguments: Dict[str, Any]) -> List[TextContent]:
        """Handle tool calls"""
        try:
            if name == "git_status":
                result = await git_mcp.git_status(arguments)
            elif name == "git_diff":
                result = await git_mcp.git_diff(arguments)
            elif name == "git_log":
                result = await git_mcp.git_log(arguments)
            elif name == "git_branch":
                result = await git_mcp.git_branch(arguments)
            elif name == "git_add":
                result = await git_mcp.git_add(arguments)
            elif name == "git_commit":
                result = await git_mcp.git_commit(arguments)
            elif name == "git_push":
                result = await git_mcp.git_push(arguments)
            elif name == "git_pull":
                result = await git_mcp.git_pull(arguments)
            else:
                result = f"Unknown tool: {name}"

            return [TextContent(type="text", text=result)]
        except Exception as e:
            return [TextContent(type="text", text=f"Error: {str(e)}")]

    # Run the server
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream, write_stream, server.create_initialization_options()
        )


if __name__ == "__main__":
    asyncio.run(main())
