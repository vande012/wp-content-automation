# Technology Stack

## Core Technologies

| Technology | Purpose | Key Dependency |
|------------|---------|----------------|
| **Runtime** | Execution Environment | Node.js >= 20.9.0 |
### 1. Frontend & UI
- **Next.js 16**: Modern React framework for the management dashboard.
- **React 19**: Latest React features for interactive components.
- **Tailwind CSS**: Utility-first CSS for rapid, consistent styling.
- **shadcn/ui**: Accessible, customizable component primitives.
- **Lucide React**: Vector icons for the UI.

### 2. Backend & Persistence
- **Supabase**: Managed PostgreSQL database and Authentication provider.
- **Prisma ORM**: Type-safe query builder and migration tool.
- **BullMQ**: High-performance Redis-based job queue for async scraping.
- **Redis**: In-memory data structure store used as the BullMQ backend.

### 3. Core Automation (The "Scraper")
- **Playwright ^1.40.0**: Headless browser automation (Chromium).
- **JSDOM ^23.2.0**: DOM emulation for server-side HTML cleaning.
- **Cheerio ^1.0.0-rc.12**: Fast, flexible HTML parsing for lightweight extraction.
- **fs-extra**: Adds promise support and convenience methods (like `ensureDir`) to the standard `fs` module.
- **winston**: Standardized logging for CLI execution debugging.

### Development Dependencies
- **@types/node**: Type definitions for better IDE support.
- **Playwright Browser Binaries**: Necessary for the automation service to function.

## Architectural Choices

- **Modular Services**: Decoupling scraping, processing, and exporting ensures that any single failure doesn't require a full restart of the entire pipeline.
- **Bootstrap-First Sanitization**: The decision to preserve Bootstrap classes while stripping others balances the need for clean, portable HTML with the need for visually consistent layout in WordPress.
- **JSON-Based State**: Using `json` files for image mapping and URL tracking ensures that the pipeline is easy to inspect and debug during development.
- **Singleton Config**: Centralizing configuration management prevents "config-drift" across different services and simplify environment-based deployments.
