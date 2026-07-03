# VoiceAccount

VoiceAccount is a dark-mode iOS expense tracker focused on fast daily bookkeeping. It supports manual expense entry, voice recording upload, AI-assisted parsing, local history, statistics, category management, CSV export, and local data clearing.

## Project Structure

```text
VoiceAccountClient/   SwiftUI iOS app and HTML prototypes
VoiceAccountServer/   Flask backend for audio upload and AI parsing
```

## Features

- Four main tabs: accounting, statistics, history, and settings
- Manual expense entry with amount, title, time, and category
- Voice recording upload as `.m4a`
- AI parsing endpoint for extracting expense items from audio
- Local storage for records and categories
- Category create, edit, delete, icon, and color management
- CSV export and local data reset

## iOS App

Open the Xcode project:

```bash
open VoiceAccountClient/VoiceAccount.xcodeproj
```

The app stores expense data locally on device. The voice upload feature expects the Flask server to be reachable from the iPhone or simulator.

## Backend

Create a virtual environment and install dependencies:

```bash
cd VoiceAccountServer
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Create a `.env` file based on `.env.example`, then start the server:

```bash
python app.py
```

Required services:

- Supabase Storage bucket named `user-audio`
- DashScope/OpenAI-compatible API key for AI audio expense parsing

## Notes

This repository is intended as an open-source prototype and learning project. Do not commit local `.env` files, API keys, virtual environments, or Xcode derived data.
