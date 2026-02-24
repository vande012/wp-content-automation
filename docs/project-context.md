---
project_name: 'wp-content-automation'
user_name: 'Ryanvandehey'
date: '2026-01-06T14:24:00Z'
sections_completed: ['technology_stack', 'architectural_patterns', 'implementation_rules']
existing_patterns_found: 12
---

# Project Context: wp-content-automation

This document provides critical implementation rules and architectural context optimized for AI coding assistants. Focus on these rules to maintain consistency and prevent common implementation mistakes.

## 🛠 Technology Stack (Verified)

- **Runtime**: Node.js >= 20.9.0 (ECMAScript Modules; Next.js requirement)
- **Scraping**: Playwright ^1.40.0 (Chromium)
- **DOM Engine**: JSDOM ^23.2.0 (for complex cleaning), Cheerio ^1.0.0-rc.12 (for lightweight extraction)
- **Utilities**: fs-extra ^11.1.1, p-queue ^7.4.1, winston ^3.11.0
- **UI/CLI**: blessed-contrib, reblessed (Dashboard-style CLI)

## 🏗 Architectural Patterns

- **Layered Service Architecture**: 
  - `src/core/`: Heavy lifting (Scraper, Processor, etc.)
  - `src/cli/`: Minimal wrappers/orchestrators
  - `src/config/`: Single source of truth for all paths and settings
- **Pipeline Flow**: Input (URLs) → Scraping (HTML) → Image Sync → Content Processing → CSV Export
- **Resiliency Wrapper**: Centralized `retry` logic in `src/utils/errors.js` for all volatile operations.

## 🚨 Critical Implementation Rules

### 1. HTML Sanitization (Strict Enforcement)
When modifying the `ContentProcessorService`, follow the aggressive cleaning rule:
- **Remove ALL** `id` and `class` attributes.
- **WHITELIST EXCEPTIONS**: Preserve Bootstrap layout classes:
  - `row`, `container`, `container-fluid`, `col-*`
  - `text-left`, `text-center`, `text-right`
- **Dealer Specifics**: Maintain `.dealer-name` or `.inventory-item` if explicitly needed for metadata extraction.

### 2. Persistence Layer (Prisma)
- **Client Usage**: Always use the singleton client from `@/lib/db/client`.
- **Migrations**: Never modify `schema.prisma` without documenting the change in `PRISMA_SETUP.md`.
- **Querying**: Favor `findUnique` and `upsert` for idempotent record management in the scraper pipeline.

### 3. Frontend (Next.js & React)
- **App Router**: Use `/app` for all routes. Components must be Server Components by default.
- **UI primitives**: Always use shadcn components from `@/components/ui`. Do not create ad-hoc styled components.
- **Auth**: Use the `middleware.ts` logic for route protection. Check sessions via Supabase server-side helpers in layouts.

### 4. Job Management (BullMQ)
- **Naming**: Use descriptive job names (e.g., `scrape-dealer-xyz`).
- **Retries**: Configure exponential backoff for all scraping jobs to handle network flakiness.

### 5. Git Hooks (Husky)
- **Hooks Path**: Keep `core.hooksPath` pointing to `.husky/_` and manage hooks in `.husky/`.

## 📂 Knowledge Mapping
- **Overview**: `_bmad-output/project-overview.md`
- **Architecture**: `_bmad-output/architecture.md`
- **Dev Guide**: `_bmad-output/development-guide.md`
