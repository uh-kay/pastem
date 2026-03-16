[![Built with Gleam](https://img.shields.io/badge/built%20with-gleam-ffaff3?logo=gleam)](https://gleam.run)

# Pastem

Paste service written in Gleam.

## Features

- Create, update and delete pastes
- User authentication and authorization
- Pagination

## Architecture

| Component | Description |
| --------- | ----------- |
| Backend | Wisp + Mist |
| Frontend | Lustre for HTML rendering (or SPA) |
| Storage | PostgreSQL |
| Security | Password based auth or magic link auth |
