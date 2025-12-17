#!/usr/bin/env python3
"""
TUI Stream Server - Audio conference relay server

Accepts multiple client connections and relays audio streams between them.
Each client's audio is sent to all other connected clients.
"""

import argparse
import asyncio
import json
import logging
import struct
import sys
from dataclasses import dataclass, field
from typing import Dict, Set

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Protocol constants
HEADER_SIZE = 8  # 4 bytes client_id + 4 bytes payload_size
MSG_TYPE_AUDIO = 1
MSG_TYPE_CONTROL = 2


@dataclass
class Client:
    client_id: int
    name: str
    reader: asyncio.StreamReader
    writer: asyncio.StreamWriter
    addr: tuple


@dataclass
class Server:
    clients: Dict[int, Client] = field(default_factory=dict)
    next_client_id: int = 1
    lock: asyncio.Lock = field(default_factory=asyncio.Lock)

    async def broadcast_client_list(self):
        """Send updated client list to all clients."""
        client_list = [
            {"id": c.client_id, "name": c.name}
            for c in self.clients.values()
        ]
        msg = json.dumps({"type": "client_list", "clients": client_list}).encode()
        await self.broadcast_control(msg, exclude_id=None)

    async def broadcast_control(self, data: bytes, exclude_id: int = None):
        """Broadcast control message to all clients."""
        header = struct.pack(">BHI", MSG_TYPE_CONTROL, 0, len(data))
        async with self.lock:
            for client in list(self.clients.values()):
                if exclude_id and client.client_id == exclude_id:
                    continue
                try:
                    client.writer.write(header + data)
                    await client.writer.drain()
                except Exception as e:
                    logger.warning(f"Failed to send to client {client.client_id}: {e}")

    async def broadcast_audio(self, sender_id: int, audio_data: bytes):
        """Broadcast audio from one client to all others."""
        header = struct.pack(">BHI", MSG_TYPE_AUDIO, sender_id, len(audio_data))
        async with self.lock:
            for client in list(self.clients.values()):
                if client.client_id == sender_id:
                    continue
                try:
                    client.writer.write(header + audio_data)
                    await client.writer.drain()
                except Exception as e:
                    logger.warning(f"Failed to send audio to client {client.client_id}: {e}")

    async def handle_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        addr = writer.get_extra_info('peername')
        logger.info(f"New connection from {addr}")

        # Read client name (first message)
        try:
            name_len_data = await asyncio.wait_for(reader.readexactly(4), timeout=10)
            name_len = struct.unpack(">I", name_len_data)[0]
            name = (await reader.readexactly(name_len)).decode('utf-8')
        except Exception as e:
            logger.error(f"Failed to read client name from {addr}: {e}")
            writer.close()
            await writer.wait_closed()
            return

        # Register client
        async with self.lock:
            client_id = self.next_client_id
            self.next_client_id += 1
            client = Client(
                client_id=client_id,
                name=name,
                reader=reader,
                writer=writer,
                addr=addr
            )
            self.clients[client_id] = client

        logger.info(f"Client '{name}' (id={client_id}) connected from {addr}")

        # Send client their ID
        welcome = json.dumps({"type": "welcome", "your_id": client_id}).encode()
        header = struct.pack(">BHI", MSG_TYPE_CONTROL, 0, len(welcome))
        writer.write(header + welcome)
        await writer.drain()

        # Broadcast updated client list
        await self.broadcast_client_list()

        # Handle incoming audio
        try:
            while True:
                # Read message header: 1 byte type + 4 bytes size
                header_data = await reader.readexactly(5)
                msg_type, size = struct.unpack(">BI", header_data)

                if msg_type == MSG_TYPE_AUDIO:
                    audio_data = await reader.readexactly(size)
                    await self.broadcast_audio(client_id, audio_data)
                elif msg_type == MSG_TYPE_CONTROL:
                    # Control messages from client (e.g., name change)
                    control_data = await reader.readexactly(size)
                    # Handle control messages if needed
                    pass
        except asyncio.IncompleteReadError:
            logger.info(f"Client '{name}' (id={client_id}) disconnected")
        except Exception as e:
            logger.error(f"Error handling client '{name}' (id={client_id}): {e}")
        finally:
            # Remove client
            async with self.lock:
                if client_id in self.clients:
                    del self.clients[client_id]
            writer.close()
            await writer.wait_closed()

            # Notify others
            leave_msg = json.dumps({"type": "client_left", "id": client_id, "name": name}).encode()
            await self.broadcast_control(leave_msg)
            await self.broadcast_client_list()
            logger.info(f"Client '{name}' (id={client_id}) removed")


async def main():
    parser = argparse.ArgumentParser(description='TUI Stream Server - Audio conference relay')
    parser.add_argument('-p', '--port', type=int, default=9999, help='Port to listen on (default: 9999)')
    parser.add_argument('-b', '--bind', default='0.0.0.0', help='Address to bind to (default: 0.0.0.0)')
    args = parser.parse_args()

    server = Server()

    async def client_handler(reader, writer):
        await server.handle_client(reader, writer)

    srv = await asyncio.start_server(client_handler, args.bind, args.port)
    addr = srv.sockets[0].getsockname()
    logger.info(f"TUI Stream Server listening on {addr[0]}:{addr[1]}")
    logger.info("Waiting for clients...")

    async with srv:
        await srv.serve_forever()


if __name__ == '__main__':
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Server shutting down")
        sys.exit(0)
