# 🎓 Assignix

Assignix is a modern, gamified learning platform designed for students to master programming and for teachers to manage classrooms, assignments, and coding challenges seamlessly. Built with a robust **React + Vite** frontend and backed by **Supabase**, it brings real-time collaboration and instant code execution together in a sleek, developer-centric interface.

---

## ✨ Features

### 💻 Student & Coding Experience
*   **Interactive Code Workspace**: Solve challenges using an embedded **Monaco Editor** (the engine powering VS Code) with syntax highlighting, auto-completions, and layout customizability.
*   **Multi-Language Execution**: Execute code instantly in **Python**, **JavaScript**, **C**, **C++**, and **Java** powered by a secure compilation runner.
*   **Gamified Learning**: Track progress with daily streaks, level up using **XP rewards**, and view problem-solving stats dynamically.
*   **Social & Real-Time Interaction**: Connect with peers, accept friend requests, and get live notifications when challenges are updated, powered by real-time database subscriptions.

### 🏫 Teacher & Admin Dashboard
*   **Classroom Management**: Create virtual classrooms, manage student lists, and assign custom programming tasks.
*   **Challenge Editor**: Handcraft problems with description markdown, runtime constraints, and custom test suites.
*   **Plagiarism & Security Guardrails**: Row-Level Security (RLS) constraints coupled with database-level triggers to enforce data ownership and secure validation flows.

---

## 🛠️ Tech Stack

*   **Frontend**: React (v19), Vite, Tailwind CSS (v4), Monaco Editor, Framer Motion, Recharts, Lucide Icons.
*   **Backend/Database**: Supabase (Postgres, Auth, Edge Functions, Real-time Channels).
*   **Code Runner**: OneCompiler API.

---

## 🚀 Getting Started

### Prerequisites
Make sure you have [Node.js](https://nodejs.org/) (v18+) and `npm` installed.

### 1. Clone the Repository
```bash
git clone https://github.com/Shashankverma-dev/assignix.git
cd assignix
```

### 2. Set Up Environment Variables
Create a `.env` file inside the `client` directory:
```bash
cp client/.env.example client/.env
```
Populate it with your Supabase credentials and compiler API key:
```env
VITE_SUPABASE_URL=your_supabase_project_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
VITE_ONECOMPILER_API_URL=https://onecompiler-apis.p.rapidapi.com/api/v1/run
VITE_RAPIDAPI_KEY=your_rapid_api_key
VITE_RAPIDAPI_HOST=onecompiler-apis.p.rapidapi.com
```

### 3. Install & Start Development Server
From the root directory, install all monorepo dependencies and launch the client server:
```bash
# Install root & workspace packages
npm run install-all

# Run client development server
npm run client
```

Open **[http://localhost:5173/](http://localhost:5173/)** to see the application in action.

---

## 📁 Repository Structure

```text
├── client/                     # React SPA Client Codebase
│   ├── src/
│   │   ├── components/         # Premium UI Components & Layouts
│   │   ├── context/            # AuthContext (Supabase) & Global Contexts
│   │   ├── pages/              # Admin, Classroom, Code Arena & Profile Pages
│   │   ├── services/           # Code Runner (RapidAPI) & DB Services
│   │   └── config/             # Supabase Client Configuration
├── supabase/                   # Database Migrations & Policies
│   ├── functions/              # Edge functions (e.g. Delete User)
│   ├── schema.sql              # Core Schema Tables (Users, Friendships, Problems)
│   └── policies.sql            # Granular Row-Level Security (RLS) Policies
```

---

## 🔒 Security & Database Triggers

Assignix relies heavily on database triggers to ensure a fast, robust, and zero-trust structure:
*   **`handle_new_user`**: Listens to Supabase Auth (`auth.users`) to automatically spin up a public profile with safe usernames, streaks, and roles (`student`, `teacher`, `admin`).
*   **Friendship Integrity**: Bidirectional friend request acceptances and cascade removals are automatically processed at the database layer.
*   **Submission Guardrails**: Disallows manual client-side manipulation of problem statuses; accepted statuses can only be granted via signed, verified backend execution.

