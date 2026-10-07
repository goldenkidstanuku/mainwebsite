# Golden Kids School — Modern Website & School Management Portal

A modern, high-utility, responsive web application and school management portal for **Golden Kids School** ("Where Curiosity Meets Excellence"). Built with clean Vanilla JavaScript, responsive CSS design system, and full Supabase backend integration, with robust offline/demo capabilities.

---

## Key Features

### Public Website & Academic Calendar
- **Leadership Spotlight & Educational Biography**: Message and philosophy from **Smt. B.UMA** (Secretary & Correspondent), Golden Kids English Medium School, Palangi ("Teaching Runs in My Blood").
- **13 GOLDENKIDS Features**: Digitally equipped classrooms (Tablet to TV), AC seminar hall, kids game zone, maths lab cum library, CC camera surveillance, mineral water plant, fully sanitized washrooms, etc.
- **STEAM Educational Approach & NEP 2020**: Holistic pedagogy, "Less Content, More Learning", inquiry-based experiential education.
- **Public Academic Calendar (`/calendar`) — No Login Needed**:
  - Live Google Calendar synchronization (`goldenkids.academic@gmail.com`).
  - Category filters: All, Exams, Academic Terms, Recognized Holidays, and Parent-Teacher Meetings.
  - Multi-view display: Cards Grid View, Detailed Table View, and Live Google Calendar Embed Frame.
  - 1-click **Add to Google Calendar** links for every event.
  - Full search by keywords, exams, or syllabus topics.
- **Online Admissions Form**: 4-step interactive application form with instant validation and confirmation.
- **Interactive FAQ**: Accordion FAQ addressing student-teacher ratio, transport, admissions, and scholarships.
- **Contact & Visit Scheduler**: Interactive inquiry form and campus contact details.
- **Theme Support**: Seamless Dark Mode / Light Mode with system preference detection.

### WhatsApp-First Parent Communication
- **Zero Login Barrier**: Parents do not need credentials or dashboard logins.
- **Daily Automated WhatsApp Digests**: Attendance status (`Present`, `Late`, `Absent`), homework assignments, and exam schedules are pushed directly to each parent's registered WhatsApp number.
- **Instant Test Delivery**: Direct WhatsApp click-to-chat links for instant teacher and admin testing.

---

## Staff & Administration Portals

### 1. Teacher Portal (`/teacher/dashboard` & `/login/teacher`)
- **Daily Attendance Register & WhatsApp Broadcast**:
  - Record attendance with single-click `P`, `L`, `A` marks or "Mark All Present".
  - Parent WhatsApp contacts column with inline editing.
  - 1-click direct WhatsApp message button per student.
  - **Broadcast Daily WhatsApp**: Queue and send daily progress digests to all parents with one click.
- **Faculty Academic Calendar (`/teacher/calendar`)**:
  - Live status and connection to school Google Calendar (`goldenkids.academic@gmail.com`).
  - **Add School Event / Exam** modal: Add exams and holidays that instantly sync to the public calendar, the daily WhatsApp message, and Google Calendar.
  - **Google Calendar Settings**: Configure calendar ID, Gmail address, and embed options.
- **Assigned Classes & Subjects**: Overview of classes and enrolled students.
- **Homework Assignments**: Assign homework tasks that automatically populate into the parent daily WhatsApp digest.
- **Gallery Uploads**: Upload event photos and milestones.

### 2. Founder / Principal / Admin Portal (`/founder` & `/login/founder`)
- **Master Student Directory & Enrollment (`/founder/students`)**:
  - **"+ Add New Student" Modal**: Enroll new students with full name, auto-suggested roll number, class assignment, date of birth, gender, blood group, parent name, and parent WhatsApp contact.
  - **WhatsApp Opt-in Preferences**: Toggle automated daily attendance & academic WhatsApp dispatches per student.
  - **Inline Editing & Removal**: Edit student records, update parent phone numbers, or remove students.
  - **Direct WhatsApp Testing**: Test dispatch to the parent's WhatsApp number with one click.
  - **Filter & Search**: Search students by name, roll number, or parent phone number, and filter by class.
- **Admissions Processing**: Review admission applications with one-click status transitions (Pending, Accepted, Rejected).
- **Class & Grade Management**: Manage sections, grade levels, and capacity.
- **School Settings**: Update school name, address, contact details, timings, and branding.

---

## Getting Started

### Local Development (Zero Dependencies Required)
No Node.js or Python installation is required on Windows!

1. **Option 1 (One-Click)**:
   Double-click `start.bat` in the project root folder.

2. **Option 2 (PowerShell)**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File ./serve.ps1
   ```

3. Open `http://localhost:3000` in your web browser, or simply double-click `index.html` to run via `file:///` directly.

---

## Staff Demo Credentials

Use any of the faculty or administration demo accounts on the `/login` page:

| Portal Role | Official Email | Demo Password | Scope |
| :--- | :--- | :--- | :--- |
| **Faculty / Teacher** | `teacher@goldenkids.edu` | `GoldenKids2026` | Class rosters, daily attendance, WhatsApp broadcast, events |
| **Founder / Admin** | `founder@goldenkids.edu` | `GoldenKids2026` | Master student directory, enrollment, admissions, settings |

---

## Database & Supabase Setup

The database schema is organized under `supabase/migrations/`:
- `001_core_profiles_classes.sql`: Profiles, roles, classes, sections, subjects, school settings.
- `002_students_teachers_parents.sql`: Student records, teacher assignments, parent-student links.
- `003_attendance_announcements_events.sql`: Attendance logs, announcements, calendar events.
- `004_gallery_docs_messages_tables.sql`: Photo albums, documents, messaging threads.
- `005_gallery_docs_messages_policies.sql`: Row-level security (RLS) policies.
- `006_fees_exams_results_audit_notifications.sql`: Fee structures, payments, exams, grades, audit logs.

To connect your own Supabase instance, update `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `app.js`.

---

## Deployment

The project is pure modern web code (HTML5, CSS3, ES Modules). It can be deployed on any static web hosting platform:
- **Netlify**: Drag and drop the folder, or push to GitHub.
- **Vercel**: Run `vercel` or link your repository.
- **GitHub Pages**: Push to repository and enable GitHub Pages on the root folder.
- **Cloudflare Pages / AWS S3 / Firebase Hosting / Nginx / Apache / IIS**: Zero build step required.

---

## License
MIT License. Golden Kids School — All Rights Reserved.
