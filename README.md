# 🔊 Project Astra - Flutter Clone (Gemini Live Voice Bot)

A **minimal, real-time voice bot built in Flutter** inspired by **Google’s Project Astra** (Google I/O 2025).  
This project showcases human-like, conversational AI interactions using the **Gemini Live API**, replicating the **bidirectional voice-first UX** shown in Astra’s futuristic demos.

---

## 🚀 What is Project Astra?

> _“An AI agent that sees and hears what you do, understands your context, and speaks naturally back to you — like a real-time assistant.”_  
— Google I/O 2025

Project Astra is Google's vision for **multimodal, conversational AI**. The demo showed:

- A user **talking naturally** while fixing a bicycle.
- Astra **responding in real-time** (not waiting for full turns).
- Understanding what’s on-screen, highlighting objects (e.g., tools).
- Playing videos, guiding steps, and maintaining continuous voice interaction.

While Astra is still under active development with features "coming soon", Google has opened early access to the **Gemini Live API** with support for **streamed voice and visual input**.

---

## 🎯 What This Project Implements (in Flutter)

This repo is a **Flutter-based real-time voice bot**, inspired by Astra, built using the **Gemini Live API’s** current capabilities.

### ✅ Features:
- 📡 **Real-time bidirectional voice** using WebSockets
- 🎙️ Streams your microphone audio to a Python FastAPI backend
- 🤖 AI responds **in natural voice**, streamed back instantly
- 💬 **Subtitles** display live transcription as the AI speaks
- 🔄 Human-like: You can interrupt, ask follow-ups, or respond mid-conversation — just like talking to a person

### 🔧 Under the Hood:
- Uses `Gemini 2.5 Flash (preview-native-audio-dialog)` model
- Audio transcription enabled via:
  ```python
  config = types.LiveConnectConfig(
      response_modalities=["AUDIO"],
      output_audio_transcription=types.AudioTranscriptionConfig()
  )
- Backend: Python + FastAPI + WebSockets
- Frontend: Flutter with custom audio recorder + player for low-latency playback

You can checkout backend I wrote in [Project Astra Backend](https://github.com/AdnanKhan45/project-astra-backend) repository. You can run this backend locally by using the guide in this repository and run this flutter project side by side to have an overview of Project Astra Clone in Flutter.

A video on this topic to understand full backend and frontend and its result in action is coming on [eTechViral](https://www.youtube.com/@ETechViral) subscribe and hit the bell icon to stay tuned.

If you found this helpful ⭐️ the repository :) 
