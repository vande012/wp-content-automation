---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments:
  # Current Documentation
  - '_bmad-output/epics.md'
  - '_bmad-output/project-context.md'
  - '_bmad-output/project-overview.md'
  - '_bmad-output/index.md'
  - '_bmad-output/architecture.md'
  - '_bmad-output/development-guide.md'
  - '_bmad-output/technology-stack.md'
  - '_bmad-output/source-tree-analysis.md'
  - '_bmad-output/project-scan-report.json'
  - '_bmad-output/sprint-status.yaml'
  - '_bmad-output/implementation-readiness-report-2026-01-07.md'
  # Archive Documentation (Comprehensive but Outdated)
  - '_bmad-output/.archive/architecture.md'
  - '_bmad-output/.archive/development-guide.md'
  - '_bmad-output/.archive/technology-stack.md'
  - '_bmad-output/.archive/index.md'
  - '_bmad-output/.archive/project-overview.md'
  - '_bmad-output/.archive/source-tree-analysis.md'
  - '_bmad-output/.archive/comprehensive-analysis.md'
  - '_bmad-output/.archive/project-scan-report.json'
hasProjectContext: true
hasArchiveDocumentation: true
reconciliationMode: 'archive-merge'
workflowType: 'architecture'
lastStep: 0
project_name: 'wp-content-automation'
user_name: 'Ryanvandehey'
date: '2026-01-07T17:56:00Z'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### System Overview

**wp-content-automation** (internal name: wp-content-automationr) is a sophisticated **hybrid automation ecosystem** that has evolved from a pure Node.js CLI tool into a comprehensive platform featuring:

- **CLI Automation Engine**: High-performance content scraping, processing, and WordPress export pipeline
- **Web Management Dashboard**: Next.js 16 application for centralized site profile management, job monitoring, and metrics visualization
- **Database Persistence Layer**: Supabase PostgreSQL with Prisma ORM for tracking profiles, runs, and metrics
- **Async Job Processing**: BullMQ/Redis queue for offloading long-running scraping operations from the web thread

**Primary Mission**: Extract content from JavaScript-heavy automotive dealership websites, sanitize HTML while preserving Bootstrap structure, download/organize images, and generate WordPress-ready CSV imports.

### Requirements Overview

#### Functional Requirements - Core Platform

**Content Automation Pipeline (FR-CORE-1 through FR-CORE-6):**
- Web scraping from URLs with Cloudflare protection bypass (Playwright headless browser)
- Image extraction, downloading, and WordPress-friendly path mapping
- HTML sanitization with aggressive class/ID removal except Bootstrap layout classes
- Internal link conversion to WordPress-friendly URLs
- Content type detection (posts vs pages) via custom selectors
- WordPress CSV generation compatible with Really Simple CSV Importer v1.3+

**Web Dashboard (FR-WEB-1 through FR-WEB-4):**
- User authentication via Supabase Auth
- Site profile CRUD operations (dealer configurations)
- Trigger and monitor automation runs in real-time
- View metrics and logs for completed scraping jobs

**Database Persistence (FR-DB-1 through FR-DB-3):**
- Store site profiles with dealer-specific configurations
- Track automation run history with timestamps and status
- Record metrics (pages scraped, images downloaded, processing time)

**CI/CD Automation (FR-CICD-1 through FR-CICD-18):**
*(In Progress - Epics 1-6)*
- Conventional commit enforcement (FR1, FR2)
- Pre-commit linting and testing (FR3, FR4)
- Pre-push protected branch validation (FR5, FR6)
- Semantic versioning automation (FR7, FR8, FR9)
- GitHub Actions PR validation (FR10, FR11, FR12)
- Automated release pipeline (FR13, FR14, FR15, FR16)
- BMAD workflow integration (FR17, FR18)

#### Non-Functional Requirements

**Performance & Scalability (NFR-PERF-1 through NFR-PERF-4):**
- Sequential URL processing (concurrency=1) to prevent overwhelming target servers
- Concurrent image downloads with configurable rate limiting (default: 5 concurrent via p-queue)
- Timeout configuration prevents hanging operations (default: 60s page load, 30s image download)
- Memory-efficient file operations for large HTML processing

**Reliability & Resilience (NFR-REL-1 through NFR-REL-3):**
- Exponential backoff retry mechanism for network failures (default: 2-3 attempts)
- Circuit breaker pattern stops retrying after consecutive failures
- Graceful degradation when optional services unavailable (NFR9: Claude CLI, doc generation)

**Security & Access Control (NFR-SEC-1 through NFR-SEC-3):**
- HTML sanitization prevents XSS via aggressive attribute removal
- Supabase Auth for web dashboard authentication
- Route protection via Next.js middleware (server-side session checks)

**Maintainability & Developer Experience (NFR-MAINT-1 through NFR-MAINT-5):**
- Intermediate developer maintainability (NFR4)
- Clear, actionable error messages (NFR2)
- Comprehensive logging via Winston (file transports for CLI, console for dev mode)
- Configuration-driven behavior via centralized Config singleton
- Real-time progress tracking for long-running operations

**Operational (NFR-OPS-1 through NFR-OPS-2):**
- Blocking enforcement for git hooks (NFR1)
- Deterministic semantic versioning based on conventional commits (NFR8)
- CI/CD cost minimization - runs only when needed (NFR5)

### Scale & Complexity Assessment

**Project Complexity: Medium-High**

**Complexity Indicators:**
- **Dual execution modes**: CLI (direct Node.js) + Web (Next.js server)
- **Multi-layer architecture**: Frontend (React) + Backend (Next.js API routes) + Worker (BullMQ jobs) + Storage (Supabase)
- **External dependencies**: Playwright browser automation, Supabase managed PostgreSQL, Redis message broker
- **Domain complexity**: Web scraping requires Cloudflare bypass, dynamic content handling, intelligent content classification
- **Real-time features**: Job status monitoring, progress tracking (websockets/polling TBD)

**Primary Technical Domain: Full-Stack Web Application + CLI Tool**
- **Frontend**: React 19 + Next.js 16 App Router + Tailwind CSS + shadcn/ui components
- **Backend**: Next.js API routes + Prisma ORM + Supabase PostgreSQL
- **Worker**: BullMQ job queue + Redis
- **Automation**: Playwright (Chromium) + JSDOM + Cheerio + Node.js services

**Estimated Architectural Components:**
- **7 Core Services**: Scraper, Image Downloader, Content Processor, CSV Generator, Site Profile Manager, Run Tracker, Metrics Collector
- **4 Infrastructure Layers**: UI (Next.js), API (routes), Persistence (Prisma/Supabase), Queue (BullMQ/Redis)
- **3 Execution Modes**: Web Dashboard, CLI Direct, Async Job Worker
- **1 Configuration System**: Singleton Config pattern (shared across all modes)

### Technical Constraints & Dependencies

**Hard Constraints:**

1. **Node.js >= 20.9.0**: Required runtime for ES6 modules and Next.js (`"type": "module"`)
2. **Playwright Browser Binaries**: Chromium headless browser essential for Cloudflare bypass
3. **Supabase Account**: Managed PostgreSQL + Auth provider (external dependency)
4. **Redis Instance**: Required for BullMQ job queue (local or managed)
5. **Bootstrap Class Preservation**: Whitelist must maintain layout classes (`row`, `container`, `col-*`) for WordPress theme compatibility

**Technology Lock-ins:**

- **Prisma ORM**: All database queries use Prisma Client (migration path would require ORM replacement)
- **Supabase Auth**: Authentication tied to Supabase provider (migration would require auth rewrite)
- **Next.js 16**: Web dashboard uses App Router patterns (framework-specific)
- **BullMQ**: Job queue patterns assume BullMQ API (queue library replacement costly)

**Existing Architecture Patterns to Respect (ARCH1-ARCH10):**

- **ARCH5**: Configuration uses singleton pattern - must be respected across all new features
- **ARCH7**: All BMAD artifacts must go to `_bmad-output/` folder structure
- **ARCH8**: Workflow status tracking via `bmm-workflow-status.yaml`
- **ARCH9**: Critical file validation: `src/core/`, `src/app/`, `prisma/schema.prisma`, `package.json`, `src/config/`
- **ARCH10**: Commit scopes must align with BMAD module structure (bmm, workflows, agents, automation)

**Browser & Environment:**

- **Headless Browser**: Playwright requires ~500MB for browser binaries
- **RAM**: 4GB+ recommended for processing large content sets
- **Disk Space**: Variable based on image downloads (WordPress upload structure)

### Cross-Cutting Concerns Identified

**1. Configuration Management**
- **Challenge**: Same config must work for CLI (direct execution) and Web (Next.js server) and Worker (BullMQ jobs)
- **Current Pattern**: Singleton Config class in `src/config/index.js` with environment variable override
- **Architectural Impact**: All services accept config via constructor injection; centralized defaults with runtime override

**2. Error Handling & Retry Logic**
- **Challenge**: Network failures (scraping, image downloads), rate limiting, Cloudflare blocks
- **Current Pattern**: Custom error classes per domain (ScraperError, ImageDownloadError, ProcessingError, CSVGenerationError) with centralized `retry()` utility
- **Architectural Impact**: Every network operation wrapped in retry logic; exponential backoff prevents overwhelming targets

**3. Logging & Observability**
- **Challenge**: Different logging needs for CLI (Winston files) vs Web (console/external service) vs Worker (job logs)
- **Current Pattern**: Winston logger with file transports for CLI; web logging TBD
- **Architectural Impact**: Logging strategy must span CLI/Web/Worker while maintaining context

**4. Authentication & Authorization**
- **Challenge**: Web dashboard requires auth; CLI does not
- **Current Pattern**: Supabase Auth with Next.js middleware for route protection
- **Architectural Impact**: Services must be auth-agnostic; only web layer enforces auth

**5. Job Orchestration & Concurrency**
- **Challenge**: Long-running scraping jobs block web server thread
- **Current Pattern**: BullMQ/Redis queue offloads jobs from HTTP request/response cycle
- **Architectural Impact**: Job trigger (web) vs job execution (worker) separation; progress tracking via job status polling

**6. Documentation Synchronization**
- **Challenge**: Architecture changes must trigger doc updates (FR6, NFR3)
- **Current Pattern**: BMAD framework integration via `document-project` workflow; git hooks validate doc sync
- **Architectural Impact**: Critical file changes (src/core/, src/app/, prisma/) require corresponding doc updates

**7. State Management & Persistence**
- **Challenge**: CLI historically used filesystem; Web requires database; hybrid must reconcile both
- **Current Pattern**: 
  - CLI: Outputs to `output/` directory (gitignored)
  - Web: Stores profiles/runs/metrics in Supabase PostgreSQL
  - Hybrid: CLI can optionally write to DB if configured
- **Architectural Impact**: Services must support both filesystem output AND database persistence

**8. HTML Sanitization Rules**
- **Challenge**: Aggressive cleaning (remove ALL classes/IDs) vs Bootstrap preservation (whitelist layout classes)
- **Current Pattern**: `ContentProcessorService._shouldPreserveClass()` whitelist method
- **Architectural Impact**: Whitelist maintenance required when WordPress theme changes; AI agents must follow strict cleaning rules (project-context.md Rule #1)

## Starter Template Evaluation

### Primary Technology Domain

**Full-Stack Hybrid Application + CLI Tool** based on project requirements analysis.

The system requires a dual-mode execution environment:
1. **Web Dashboard**: User-facing management interface
2. **CLI Automation**: Direct command-line execution for batch processing
3. **Worker Layer**: Async job processing for long-running operations

### Existing Technical Stack (Brownfield Foundation)

**Note:** This project has already established its technical foundation. This section documents the existing "starter" decisions rather than proposing new ones.

**Initialization History:**

The project evolved through these phases:
1. **Phase 1** (CLI-only): Pure Node.js tool with Playwright scraping
2. **Phase 2** (Hybrid): Added Next.js web dashboard + Prisma/Supabase persistence
3. **Phase 3** (Async): Added BullMQ/Redis job queue for scalability
4. **Current**: Comprehensive hybrid platform with all layers operational

### Architectural Decisions Provided by Existing Stack

**Language & Runtime:**
- **Node.js >= 20.9.0**: Required for ES6 modules and Next.js (`"type": "module"`)
- **JavaScript (ES2020+)**: Primary language for all services
- **TypeScript**: Type definitions available (`@types/node`) but not enforced
- **Module System**: Pure ES6 modules, no CommonJS

**Frontend Stack (Web Dashboard):**
- **React 19**: Latest React with modern features
- **Next.js 16**: App Router pattern (server components by default)
- **Tailwind CSS**: Utility-first styling framework
- **shadcn/ui**: Accessible, customizable component primitives built on Radix UI
- **Lucide React**: Vector icon library

**Backend & Persistence:**
- **Next.js API Routes**: RESTful endpoints in `/app/api/`
- **Prisma ORM**: Type-safe database client with migration tooling
- **Supabase PostgreSQL**: Managed database with built-in Auth
- **Supabase Auth**: Authentication provider with session management

**Async Job Processing:**
- **BullMQ**: High-performance Redis-based job queue
- **Redis**: In-memory data store for queue backend
- **Job Patterns**: Queue-based offloading of long-running scraping operations

**Core Automation (CLI Engine):**
- **Playwright ^1.40.0**: Headless Chromium for web scraping
- **JSDOM ^23.2.0**: Server-side DOM emulation for complex HTML manipulation
- **Cheerio ^1.0.0-rc.12**: Fast, lightweight HTML parsing (jQuery-like API)
- **fs-extra ^11.1.1**: Enhanced filesystem operations with promises
- **p-queue ^7.4.1**: Concurrent task queue with rate limiting

**Development Experience:**
- **Winston ^3.11.0**: Structured logging (file transports for CLI)
- **dotenv**: Environment variable management
- **Hot Reloading**: Next.js dev server for web; nodemon for CLI (if configured)
- **Git Hooks**: Husky for pre-commit/pre-push automation (Epics 1-6)

**Build Tooling:**
- **Next.js Build System**: Webpack-based build for web dashboard
- **No Build Step for CLI**: Direct Node.js execution

**Code Organization Patterns:**

```
src/
├── app/            # Next.js App Router (web UI)
├── cli/            # CLI Orchestration Layer
├── core/           # Business Logic Services
│   ├── scraper.js
│   ├── processor.js
│   ├── image-downloader.js
│   └── csv-generator.js
├── components/     # React Components
│   └── ui/         # shadcn components
├── lib/            # Shared Libraries
│   └── db/         # Prisma client
├── utils/          # Utilities (errors, filesystem)
├── config/         # Configuration Management
└── middleware.js   # Next.js route protection
```

**Testing Framework:**
- **Status**: Testing infrastructure planned but not yet implemented
- **Patterns Expected**: `*.test.js` or `*.spec.js` in `tests/` directory
- **Framework TBD**: Not yet selected

**CI/CD Automation:**
- **Status**: In progress (Epics 1-6)
- **Husky**: Git hooks for pre-commit/pre-push validation
- **Commitlint**: Conventional commit enforcement
- **GitHub Actions**: PR validation and release automation (planned)
- **standard-version**: Semantic versioning automation (planned)

### Key Architectural Constraints from Existing Stack

**Technology Lock-ins:**

1. **Prisma ORM**: All database access via Prisma Client → migration would require query layer rewrite
2. **Supabase**: Auth and PostgreSQL tied to Supabase → migration costly
3. **Next.js 16**: Web UI uses App Router patterns → framework-specific
4. **BullMQ**: Job queue API assumptions → queue library replacement expensive

**Configuration Patterns:**

- **Singleton Config**: `src/config/index.js` provides centralized configuration
- **Environment Override**: `.env` file overrides defaults
- **Service Injection**: All services accept config via constructor options

**Error Handling Patterns:**

- **Custom Error Classes**: `ScraperError`, `ImageDownloadError`, `ProcessingError`, `CSVGenerationError`
- **Centralized Retry Logic**: `retry()` utility with exponential backoff
- **Winston Logging**: Structured file-based logging

**Development Workflow:**

- **CLI Execution**: `npm start` → `node src/cli/automation.js`
- **Web Dashboard**: `npm run dev:web` → Next.js dev server on localhost:3000
- **Database**: `npm run db:migrate` → Prisma migrations
- **Database Studio**: `npm run db:studio` → Prisma visual editor

### Rationale for Current Stack

**Why This Hybrid Architecture:**

1. **CLI Performance**: Direct Node.js execution for batch processing without HTTP overhead
2. **Web Accessibility**: Next.js dashboard for non-technical users and centralized management
3. **Scalability**: BullMQ/Redis offloads long-running jobs from web server thread
4. **Developer Familiarity**: JavaScript/React ecosystem widely known
5. **Managed Services**: Supabase reduces operational burden for database/auth

**Tradeoffs Accepted:**

- **Complexity**: Hybrid architecture more complex than pure CLI or pure web
- **Vendor Lock-in**: Supabase and Prisma migration path costly
- **Maintenance Burden**: Multiple execution modes require careful config management

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Already Implemented):**
- Database & ORM Choice (Supabase + Prisma)
- Authentication Provider (Supabase Auth)
- Job Queue System (BullMQ + Redis)
- Frontend Framework (Next.js 16 App Router)
- HTML Sanitization Strategy (Aggressive with whitelist)

**Important Decisions (Shape Architecture):**
- Hybrid Execution Model (CLI + Web + Worker)
- Service-Oriented Layered Architecture
- Configuration Management (Singleton Pattern)
- Error Handling Strategy (Custom Classes + Retry Logic)
- State Persistence (Dual: Filesystem + Database)

**Deferred Decisions (Post-Current Implementation):**
- Testing Framework Selection (TBD)
- Monitoring & Observability Platform (TBD)
- Web Logging Strategy (currently Winston for CLI only)
- Real-time Update Mechanism (WebSockets vs Polling - TBD)

### Data Architecture

**Database Choice: Supabase PostgreSQL**

- **Decision**: Managed PostgreSQL via Supabase
- **Version**: Supabase (latest), PostgreSQL 15+
- **Rationale**: 
  - Managed service reduces operational burden
  - Built-in Auth integration
  - Row Level Security (RLS) capabilities
  - Generous free tier for development
- **Affects**: All web dashboard features, persistent state tracking
- **Lock-in**: Migration to self-hosted PostgreSQL possible but Auth rewrite required

**ORM Choice: Prisma**

- **Decision**: Prisma ORM for type-safe database access
- **Version**: Prisma ^5.0.0
- **Rationale**:
  - Type-safe queries prevent runtime errors
  - Declarative schema with migration tooling
  - Excellent DX with Prisma Studio
  - Auto-generated TypeScript types
- **Affects**: All database interactions in web/worker layers
- **Lock-in**: Query patterns tied to Prisma Client API

**Data Modeling Approach: Relational**

- **Decision**: Normalized relational model
- **Key Entities**:
  - `SiteProfiles`: Dealer configurations
  - `Runs`: Automation execution history
  - `Metrics`: Scraping statistics
  - `Users`: Authentication (Supabase Auth schema)
- **Schema Location**: `prisma/schema.prisma`
- **Migration Strategy**: Prisma Migrate (`npm run db:migrate`)

**Data Validation Strategy: Multi-Layer**

- **Application Layer**: Prisma schema validation (required fields, types, relationships)
- **Database Layer**: PostgreSQL constraints (unique, not null, foreign keys)
- **API Layer**: Input validation in Next.js API routes (TBD: Zod or similar)
- **Service Layer**: Business logic validation in core services

**Caching Strategy: Minimal (Current)**

- **Status**: No distributed cache currently implemented
- **Redis Usage**: Dedicated to BullMQ job queue only
- **Future Consideration**: Redis caching for frequent DB queries (site profiles, metrics)
- **Rationale for Deferral**: Premature optimization; implement when performance metrics indicate need

### Authentication & Security

**Authentication Method: Supabase Auth**

- **Decision**: Supabase managed authentication
- **Supported Methods**: Email/Password (primary), OAuth providers (future)
- **Session Management**: Server-side via Supabase helpers in Next.js
- **Token Storage**: HTTP-only cookies (secure)
- **Affects**: Web dashboard only (CLI has no auth)

**Authorization Patterns: Route-Based**

- **Decision**: Next.js middleware for route protection
- **Implementation**: `src/middleware.js` checks session on protected routes
- **Pattern**: Server Components check auth serverside before rendering
- **Strategy**: Coarse-grained (authenticated vs anonymous), no RBAC yet
- **Future**: Row Level Security (RLS) in Supabase for fine-grained control

**Security Middleware:**

- **Next.js Middleware**: Session validation on protected routes (`/dashboard/*`)
- **Supabase RLS**: Database-level authorization (planned, not yet implemented)
- **CORS**: Next.js default (same-origin)
- **Rate Limiting**: Not implemented (future consideration for API routes)

**Data Encryption Approach:**

- **In Transit**: HTTPS enforced (Supabase requires TLS)
- **At Rest**: Supabase managed encryption (PostgreSQL)
- **Secrets Management**: Environment variables (`.env`), never committed
- **Sensitive Data**: No PII stored currently (dealer configs and metrics only)

**API Security Strategy:**

- **Internal APIs**: Next.js API routes protected by middleware
- **External APIs**: None currently exposed
- **WordPress CSV Export**: Filesystem output, no API exposure
- **CLI Security**: Local execution only, no network exposure

**HTML Sanitization (XSS Prevention):**

- **Decision**: Aggressive attribute removal via `ContentProcessorService`
- **Implementation**: JSDOM-based cleaning removes ALL `class` and `id` attributes except whitelisted
- **Whitelist**: Bootstrap layout classes only (`row`, `container`, `col-*`, text alignment)
- **Rationale**: WordPress sites have varying themes; aggressive cleaning ensures portability
- **Critical Rule**: AI agents must follow `project-context.md` Rule #1 for any processor changes

### API & Communication Patterns

**API Design: REST via Next.js API Routes**

- **Decision**: RESTful API using Next.js `/app/api/*` routes
- **Pattern**: Resource-based URLs (`/api/profiles`, `/api/runs`)
- **HTTP Methods**: GET (read), POST (create), PUT/PATCH (update), DELETE (remove)
- **Response Format**: JSON
- **Error Responses**: Standardized HTTP status codes with error messages

**API Documentation Approach:**

- **Status**: Not yet implemented
- **Future Options**: OpenAPI/Swagger, or inline JSDoc
- **Rationale for Deferral**: Internal API only, no external consumers currently

**Error Handling Standards:**

**Service Layer (Core Services):**
- **Custom Error Classes**: `ScraperError`, `ImageDownloadError`, `ProcessingError`, `CSVGenerationError`
- **Error Context**: Errors include original cause, context, and user-friendly messages
- **Retry Logic**: `retry()` utility with exponential backoff for network operations
- **Circuit Breaker**: Stops retrying after consecutive failures

**API Layer (Next.js Routes):**
- **Pattern**: Try-catch with HTTP status codes
- **Client Errors (4xx)**: Bad input validation
- **Server Errors (5xx)**: Unhandled exceptions
- **Logging**: Winston for CLI, console.error for web (strategy TBD)

**CLI Layer:**
- **User-Friendly Messages**: `getUserFriendlyMessage()` translates technical errors
- **Progress Tracking**: `ProgressTracker` class monitors long operations
- **Graceful Exit**: Failed items tracked, pipeline continues

**Rate Limiting Strategy:**

- **Current**: None implemented
- **Scraping**: Sequential processing (concurrency=1) prevents overwhelming targets
- **Image Downloads**: `p-queue` limits concurrent downloads (default: 5)
- **Future**: API route rate limiting if abuse detected

**Communication Between Services:**

**CLI ↔ Core Services:**
- **Pattern**: Direct function calls (same process)
- **Mechanism**: Service instantiation with config injection

**Web ↔ Core Services:**
- **Pattern**: Job queue (async) or direct calls (sync operations)
- **Mechanism**: BullMQ jobs trigger service execution in worker process

**Web ↔ Database:**
- **Pattern**: Prisma Client (ORM)
- **Connection Pool**: Managed by Prisma

**Worker ↔ Database:**
- **Pattern**: Same Prisma Client as web layer
- **Singleton**: Shared database client via `@/lib/db/client`

### Frontend Architecture

**State Management Approach: Server State + React State**

- **Decision**: Minimal client-side state; rely on Server Components
- **Global State**: None (Next.js App Router philosophy)
- **Server State**: Data fetched in Server Components, passed to Client Components
- **Local State**: React `useState` for UI-only state (modals, toggles, form inputs)
- **Form State**: Uncontrolled forms or React Hook Form (TBD per component)
- **Rationale**: Server Components reduce client bundle size and eliminate state sync complexity

**Component Architecture:**

**Organization:**
```
src/components/
├── ui/              # shadcn primitives (Button, Input, Card, etc.)
└── [feature]/       # Feature-specific components (TBD naming)
```

**Patterns:**
- **Server Components by Default**: Only add `"use client"` when needed (interactivity, hooks, browser APIs)
- **shadcn Composition**: Build complex UIs from shadcn primitives
- **Atomic Design**: Small, reusable components composed into features
- **Location**: Custom business components alongside `ui/` (flat for now, may organize by feature later)

**Routing Strategy:**

- **Decision**: Next.js App Router (file-system based)
- **Pattern**: `/app/[route]/page.tsx` for pages, `/app/[route]/layout.tsx` for nested layouts
- **Dynamic Routes**: `[slug]` for parameterized routes (e.g., `/profiles/[id]`)
- **API Routes**: `/app/api/[endpoint]/route.ts`
- **Middleware**: `src/middleware.js` for auth checks

**Performance Optimization:**

- **Server Components**: Default rendering on server reduces client JS
- **Image Optimization**: Next.js `<Image>` component (automatic optimization)
- **Code Splitting**: Automatic via Next.js dynamic imports
- **Bundle Analysis**: Not yet implemented (future: `@next/bundle-analyzer`)
- **Lazy Loading**: React `lazy()` for heavy Client Components (use sparingly)

**Bundle Optimization:**

- **Framework**: Next.js handles tree-shaking and minification
- **CSS**: Tailwind purges unused styles automatically
- **Fonts**: Self-hosted (Tailwind `font-*` classes or `next/font`)
- **Third-Party Scripts**: `next/script` for analytics (when needed)
- **Target**: Modern browsers (ES2020+), no legacy polyfills

### Infrastructure & Deployment

**Hosting Strategy:**

**Web Dashboard:**
- **Platform**: Vercel (recommended for Next.js) or similar Next.js-compatible host
- **Rationale**: Zero-config deployment, automatic previews, edge network
- **Alternatives**: Railway, Render, AWS Amplify

**Database:**
- **Platform**: Supabase managed PostgreSQL
- **Region**: User-selected (typically nearest to application host)

**Job Queue:**
- **Redis Hosting**: Upstash (serverless Redis) or Redis Cloud
- **Worker Execution**: Same platform as web dashboard (serverless functions or long-running process)

**CLI Execution:**
- **Platform**: Local machine or CI/CD runner
- **No Hosting Required**: CLI is developer tool, not deployed service

**CI/CD Pipeline Approach:**

**Status**: In Progress (Epics 1-6)

**Current (Implemented - Epic 1-2):**
- **Husky Git Hooks**: Pre-commit linting/testing, pre-push validation
- **Commitlint**: Conventional commit enforcement
- **Local Validation**: Developer machine quality gates

**Planned (Epics 3-6):**
- **GitHub Actions**: PR validation (`pr-validation.yml`)
  - Linting (ESLint)
  - Testing (Jest with coverage)
  - Commit message validation
  - Changelog preview generation
- **GitHub Actions**: Release automation (`release.yml`)
  - Semantic version bumping (`standard-version`)
  - CHANGELOG.md generation
  - GitHub release creation
  - Documentation regeneration (BMAD `document-project` workflow)
- **Deployment**: Manual or automatic on merge to `main` (TBD based on hosting platform)

**Environment Configuration:**

**Pattern: Environment Variables**

- **Local Development**: `.env.local` (Git-ignored)
- **Production**: Platform-specific env var management (Vercel, etc.)
- **Shared Config**: `src/config/index.js` singleton with defaults + env overrides

**Key Environment Variables:**
```bash
# Database
DATABASE_URL=postgresql://...
DIRECT_URL=postgresql://...  # Prisma direct connection

# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://...
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...

# Redis/BullMQ
REDIS_URL=redis://...

# CLI-specific
SCRAPER_HEADLESS=true
DEALER_SLUG=example-dealer
LOG_LEVEL=info
```

**Monitoring and Logging:**

**Current Implementation:**

**CLI Logging:**
- **Framework**: Winston ^3.11.0
- **Transports**: File-based (`logs/combined.log`, `logs/error.log`)
- **Format**: Timestamped, structured JSON
- **Levels**: error, warn, info, debug

**Web Logging:**
- **Status**: TBD (console.error placeholder)
- **Future Options**: Vercel Analytics, Sentry, LogRocket

**Job Worker Logging:**
- **Mechanism**: BullMQ job events + Winston (same as CLI)
- **Job Status**: Tracked in Redis (BullMQ built-in)

**Monitoring:**
- **Status**: Not implemented
- **Future Consideration**: 
  - Application: Vercel Analytics, Sentry for error tracking
  - Database: Supabase dashboard metrics
  - Infrastructure: Platform-provided monitoring

**Scaling Strategy:**

**Horizontal Scaling:**
- **Web Dashboard**: Serverless auto-scaling (Vercel handles)
- **Worker Processes**: BullMQ supports multiple workers (scale by adding worker instances)
- **Database**: Supabase auto-scales within plan limits; upgrade plan for higher load

**Vertical Scaling:**
- **Not a Primary Focus**: Serverless platforms scale out, not up

**Performance Bottlenecks (Known):**
1. **Sequential Scraping**: Concurrency=1 prevents overwhelming targets but limits throughput
   - **Mitigation**: Acceptable tradeoff for target server health
2. **Image Processing**: Large image downloads can be slow
   - **Mitigation**: Concurrent downloads (p-queue) with rate limiting
3. **Database Queries**: N+1 queries possible in Prisma if not careful
   - **Mitigation**: Use `include` for eager loading, monitor query performance

**Load Expectations:**
- **Web Dashboard**: Low (internal tool for dealership management team)
- **CLI Usage**: Batch processing, not real-time
- **Worker Jobs**: Long-running (minutes to hours per job), low concurrency (1-5 concurrent jobs expected)

### Decision Impact Analysis

**Implementation Sequence (Historical Evolution):**

1. **Phase 1 (Foundation)**: CLI-only architecture
   - Core services (Scraper, Processor, Image Downloader, CSV Generator)
   - Winston logging
   - File-system persistence
   
2. **Phase 2 (Web Dashboard)**: Hybrid CLI + Web
   - Next.js frontend
   - Prisma + Supabase database
   - Supabase Auth
   - Profile/Run management

3. **Phase 3 (Async Jobs)**: Worker layer addition
   - BullMQ job queue
   - Redis message broker
   - Offload scraping to background workers

4. **Phase 4 (CI/CD - Current)**: Automation layer
   - Husky git hooks (completed - Epic 1-2)
   - GitHub Actions (planned - Epics 3-6)
   - Semantic versioning + releases

**Cross-Component Dependencies:**

**Database (Supabase + Prisma) affects:**
- Web dashboard (all CRUD operations)
- Worker jobs (persisting run results)
- CLI (optional DB writes if configured)

**Auth (Supabase Auth) affects:**
- Web dashboard route protection
- API route authorization
- User session management

**Job Queue (BullMQ + Redis) affects:**
- Web dashboard (triggering scraping jobs)
- Worker processes (executing jobs)
- Progress tracking (polling job status)

**Configuration Singleton affects:**
- ALL services (CLI, Web, Worker use same config pattern)
- Environment variable management
- Service initialization

**Error Handling Strategy affects:**
- Service reliability (retry logic prevents transient failures)
- User experience (friendly error messages)
- Debugging (structured error context)

**HTML Sanitization Rules affect:**
- Content quality (Bootstrap preservation for layout)
- WordPress compatibility (aggressive cleaning ensures portability)
- AI agent behavior (must follow project-context.md Rule #1)

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

**Critical Conflict Points Identified:** 12 areas where AI agents could make different choices without explicit guidance

This section establishes the precise patterns all AI agents MUST follow to ensure code compatibility across the hybrid CLI/Web/Worker architecture.

### Naming Patterns

**Database Naming Conventions:**

**Table Naming:**
- **Pattern**: PascalCase singular (`SiteProfile`, not `site_profiles` or `SiteProfiles`)
- **Rationale**: Prisma schema convention; auto-pluralized in migrations
- **Example**: `model SiteProfile { ... }` in `prisma/schema.prisma`

**Column Naming:**
- **Pattern**: camelCase (`createdAt`, `dealerSlug`, not `created_at` or `dealer_slug`)
- **Rationale**: Prisma/JavaScript convention
- **Foreign Keys**: Append model name + Id (`userId`, `siteProfileId`)

**Index Naming:**
- **Pattern**: Auto-generated by Prisma (`@@index([fieldName])`)
- **Custom Names**: Only when needed for migrations (`@@index([field], name: "idx_custom")`)

**API Naming Conventions:**

**REST Endpoints:**
- **Pattern**: Plural resource names (`/api/profiles`, `/api/runs`, not `/api/profile`)
- **Resource IDs**: Dynamic segments (`/api/profiles/[id]`)
- **Actions**: Verb-based for non-CRUD (`/api/runs/[id]/restart`)

**Route Parameters:**
- **Pattern**: Next.js brackets format (`[id]`, `[slug]`)
- **Query Parameters**: camelCase (`?dealerSlug=abc`, not `?dealer_slug=abc`)

**HTTP Methods:**
- **GET**: Read operations (lists and single resources)
- **POST**: Create new resources
- **PUT/PATCH**: Update existing resources (use PATCH for partial updates)
- **DELETE**: Remove resources

**Code Naming Conventions:**

**Component Naming:**
- **React Components**: PascalCase (`UserCard`, `SiteProfileForm`)
- **File Names**: Match component name (`UserCard.tsx`, `SiteProfileForm.tsx`)
- **shadcn UI Components**: kebab-case for CLI (`button`, `card`), PascalCase in code (`<Button />`)

**Function Naming:**
- **Pattern**: camelCase verbs (`getUserData`, `createSiteProfile`, `fetchRuns`)
- **Async Functions**: No special prefix (async keyword is sufficient)
- **Event Handlers**: On-prefix (`onClick`, `onSubmit`, `onProfileSelect`)

**Variable Naming:**
- **Pattern**: camelCase (`userId`, `dealerSlug`, `scrapedContent`)
- **Constants**: SCREAMING_SNAKE_CASE (`MAX_RETRIES`, `DEFAULT_TIMEOUT`)
- **Private Fields**: Underscore prefix (`_shouldPreserveClass`, `_retryCount`)

**File Naming:**
- **React Components**: PascalCase.tsx (`ProfileCard.tsx`)
- **Utilities**: kebab-case.js (`retry-logic.js`, `date-helpers.js`)
- **Services**: kebab-case.js (`scraper.js`, `image-downloader.js`)
- **Config**: kebab-case (`next.config.js`, `tailwind.config.ts`)

### Structure Patterns

**Project Organization: Layer-Based + Feature Hybrid**

**Core Principle**: Services organized by layer, frontend by feature (when features grow)

```
src/
├── app/              # Next.js App Router (frontend + API)
│   ├── (auth)/       # Route groups for auth-related pages
│   ├── dashboard/    # Main app pages
│   ├── api/          # API routes (resource-based)
│   ├── layout.tsx    # Root layout
│   └── page.tsx      # Home/landing page
├── cli/              # CLI layer (orchestration scripts)
├── core/             # Business logic services (domain layer)
│   ├── scraper.js
│   ├── processor.js
│   ├── image-downloader.js
│   └── csv-generator.js
├── components/       # React components
│   ├── ui/           # shadcn primitives
│   └── [feature]/    # Feature-specific components (future)
├── lib/              # Shared libraries (framework wrappers)
│   ├── db/           # Database client (Prisma singleton)
│   └── supabase/     # Supabase client
├── utils/            # Pure utilities (no external dependencies)
│   ├── errors.js
│   ├── filesystem.js
│   └── cli.js
├── config/           # Configuration management
│   └── index.js      # Singleton Config class
└── middleware.js     # Next.js middleware (auth)
```

**Test Organization:**
- **Pattern**: Co-located test files (`*.test.js` next to source)
- **Directory**: Alternative option: `tests/` mirror structure (not yet implemented)
- **Naming**: `ComponentName.test.tsx` or `service-name.test.js`

**File Structure Patterns:**

**Config File Locations:**
- **Root**: `package.json`, `next.config.js`, `tailwind.config.ts`, `.env.local`
- **Tool Configs**: Root level (`.eslintrc.json`, `.prettierrc`)
- **Prisma**: `prisma/schema.prisma`, `prisma/migrations/`
- **BMAD**: `_bmad/bmm/config.yaml`, `_bmad-output/` for artifacts

**Static Assets:**
- **Public Directory**: `/public/` for Next.js static assets
- **Images**: `/public/images/` (Next.js serves from `/images/...`)
- **Output Content**: `output/` for CLI-generated content (gitignored)

**Documentation:**
- **Primary**: `README.md` at root
- **BMAD Artifacts**: `_bmad-output/*.md` (architecture, dev guide, etc.)
- **Inline Docs**: JSDoc for complex functions

### Format Patterns

**API Response Formats:**

**Success Response (200-299):**
```json
{
  "data": { ...resource },
  "meta": {
    "timestamp": "2026-01-07T20:00:00Z"
  }
}
```

**Error Response (400-599):**
```json
{
  "error": {
    "message": "User-friendly error message",
    "code": "ERROR_CODE",
    "details": { ...context }
  }
}
```

**List Response:**
```json
{
  "data": [...resources],
  "meta": {
    "count": 42,
    "page": 1,
    "pageSize": 20
  }
}
```

**Data Exchange Formats:**

**JSON Field Naming:**
- **Pattern**: camelCase for all JSON fields
- **Exception**: External APIs may use snake_case (transform on boundary)

**Date/Time:**
- **Pattern**: ISO 8601 strings (`"2026-01-07T20:00:00Z"`)
- **Storage**: PostgreSQL TIMESTAMP (handles internally)
- **Display**: Format in UI layer per locale

**Boolean Values:**
- **Pattern**: `true`/`false` (not 1/0 or "true"/"false" strings)

**Null Handling:**
- **Missing Fields**: Omit from JSON (don't send `null` for optional fields)
- **Explicit Null**: Use `null` when semantic meaning (field exists but empty)

### Communication Patterns

**Event System Patterns:**

**Status**: Not yet implemented (future: WebSockets/Server-Sent Events for real-time job progress)

**When Implemented:**
- **Event Naming**: kebab-case namespace (`job.started`, `job.progress`, `job.completed`)
- **Payload Structure**: Consistent with API response format
- **Versioning**: Include version in event type (`job.v1.started`)

**State Management Patterns:**

**Server State (Primary):**
- **Pattern**: Fetch in Server Components, pass props to Client Components
- **Revalidation**: Use Next.js `revalidatePath()` or `revalidateTag()` after mutations
- **No Global State**: Avoid Redux/Zustand; rely on Server Component refetching

**Client State (UI Only):**
- **Pattern**: React `useState` for local UI state (modals, toggles, form inputs)
- **Form State**: Uncontrolled inputs or React Hook Form for complex forms
- **No State Sync**: Client state never syncs to server except via POST/PUT

**Job Queue Communication:**
- **Pattern**: BullMQ job events (`job.on('completed', ...)`)
- **Progress Updates**: Job data updates in Redis (`job.updateProgress(percent)`)
- **Status Polling**: Web dashboard polls job status via API route

### Process Patterns

**Error Handling Patterns:**

**Service Layer (Core Services):**

**Pattern**: Custom error classes + retry wrapper

```javascript
import { ScraperError, retry } from '../utils/errors.js';

class HTMLScraperService {
  async scrapePage(url) {
    return retry(async () => {
      try {
        // Scraping logic
      } catch (err) {
        throw new ScraperError(`Failed to scrape ${url}`, { cause: err });
      }
    }, { maxAttempts: 3 });
  }
}
```

**API Layer (Next.js Routes):**

```javascript
export async function POST(request) {
  try {
    // Business logic
    return Response.json({ data: result });
  } catch (error) {
    console.error('API Error:', error);
    return Response.json(
      { error: { message: error.message, code: 'INTERNAL_ERROR' } },
      { status: 500 }
    );
  }
}
```

**CLI Layer:**

```javascript
try {
  await pipeline.run();
} catch (error) {
  logger.error('Pipeline failed:', error);
  const friendlyMessage = getUserFriendlyMessage(error);
  console.error(`Error: ${friendlyMessage}`);
  process.exit(1);
}
```

**Error Recovery:**
- **Transient Failures**: Retry with exponential backoff (network, rate limits)
- **Permanent Failures**: Log and continue pipeline (skip failed URL, continue to next)
- **Critical Failures**: Exit process (database connection lost, config error)

**Loading State Patterns:**

**Server Components:**
- **Pattern**: No loading states (SSR completes before sending HTML)
- **Suspense**: Use `<Suspense>` boundaries for streaming when needed

**Client Components:**

```typescript
'use client';

const [isLoading, setIsLoading] = useState(false);
const [error, setError] = useState<string | null>(null);

async function handleAction() {
  setIsLoading(true);
  setError(null);
  try {
    await apiCall();
  } catch (err) {
    setError(err.message);
  } finally {
    setIsLoading(false);
  }
}
```

**Global Loading**: Use Next.js `loading.tsx` files for route-level loading states

### Enforcement Guidelines

**All AI Agents MUST:**

1. **Follow HTML Sanitization Rules (`project-context.md` Rule #1)**
   - Use `ContentProcessorService._shouldPreserveClass()` whitelist
   - NEVER modify Bootstrap class removal logic without updating whitelist
   - Test with multiple WordPress themes to verify portability

2. **Use Prisma Singleton for Database Access (`project-context.md` Rule #2)**
   - Import from `@/lib/db/client` ONLY
   - NEVER instantiate `new PrismaClient()` elsewhere
   - All queries must use Prisma Client API (no raw SQL except via `prisma.$queryRaw` with type safety)

3. **Follow Next.js App Router Patterns (`project-context.md` Rule #3)**
   - Server Components by default (no `"use client"` unless needed)
   - Client Components ONLY when using: hooks, event handlers, browser APIs, third-party libs requiring client
   - Use Server Actions for mutations (not API routes unless external access needed)

4. **Use BullMQ for Async Jobs (`project-context.md` Rule #4)**
   - Long-running operations (>30s) MUST be queued
   - Job execution in worker process, not web server
   - Job progress tracked via BullMQ job data updates

5. **Respect Git Hook Validation (`project-context.md` Rule #5)**
   - Conventional commits enforced (feat/fix/docs/etc.)
   - Pre-commit: linting and tests must pass
   - Pre-push: protected branches (main/dev) require full validation
   - Emergency bypass: `--no-verify` flag documented in story 2.4

6. **Use Configuration Singleton**
   - Access config via `import { config } from '@/config'`
   - Override defaults via environment variables only
   - Service constructors accept `options` for config injection

7. **Follow Established File Organization**
   - New services in `src/core/`
   - New utilities in `src/utils/`
   - New React components in `src/components/` (ui/ for shadcn, features/ for business logic)
   - New API routes in `src/app/api/[resource]/route.ts`

8. **Use Custom Error Classes**
   - Domain-specific errors (ScraperError, ProcessingError, etc.)
   - Include context and original cause
   - Wrap network calls in `retry()` utility

9. **Log Consistently**
   - CLI: Winston logger (`logger.info()`, `logger.error()`)
   - Web: console with structured context (future: external service)
   - Include timestamps, context, and error stack traces

10. **Maintain Type Safety**
    - Prisma auto-generates types for database models
    - Use TypeScript for new files when type safety is critical
    - No `any` types except when unavoidable (external libs)

### Pattern Examples

**Good Examples:**

**Service with Config Injection:**
```javascript
import { config } from '../config/index.js';
import { ScraperError, retry } from '../utils/errors.js';

class HTMLScraperService {
  constructor(options = {}) {
    this.config = { ...config.get('scraper'), ...options };
  }

  async scrapePage(url) {
    return retry(async () => {
      // Implementation
    }, { maxAttempts: this.config.retries });
  }
}
```

**API Route with Error Handling:**
```javascript
// src/app/api/profiles/route.ts
import { db } from '@/lib/db/client';

export async function GET() {
  try {
    const profiles = await db.siteProfile.findMany();
    return Response.json({ data: profiles });
  } catch (error) {
    return Response.json(
      { error: { message: 'Failed to fetch profiles', code: 'DB_ERROR' } },
      { status: 500 }
    );
  }
}
```

**Server Component with Data Fetching:**
```typescript
// src/app/dashboard/profiles/page.tsx
import { db } from '@/lib/db/client';
import { ProfileList } from '@/components/ProfileList';

export default async function ProfilesPage() {
  const profiles = await db.siteProfile.findMany();
  return <ProfileList profiles={profiles} />;
}
```

**Anti-Patterns (AVOID):**

**❌ Direct Prisma Instantiation:**
```javascript
// WRONG - creates connection pool leak
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();
```

**❌ Client Component for Static Content:**
```typescript
// WRONG - unnecessary client bundle
'use client';

export default function StaticPage() {
  return <div>Static content</div>;
}
```

**❌ Unhandled API Errors:**
```javascript
// WRONG - exposes internal errors to client
export async function POST(request) {
  const result = await db.someModel.create({ data });
  return Response.json(result);  // No try-catch!
}
```

**❌ Hard-coded Config:**
```javascript
// WRONG - not configurable
const MAX_RETRIES = 3;

// CORRECT
const MAX_RETRIES = config.get('scraper').retries;
```

**❌ Mixed Naming Conventions:**
```javascript
// WRONG - inconsistent
const user_id = data.userId;
const UserName = data.user_name;

// CORRECT
const userId = data.userId;
const userName = data.userName;
```
## Project Structure & Boundaries

### Complete Project Directory Structure

```
wp-content-automation/
├── Root Configuration Files
├── package.json                # Node.js project manifest, dependencies
├── package-lock.json           # Locked dependency versions
├── next.config.js              # Next.js configuration
├── tailwind.config.js          # Tailwind CSS configuration
├── postcss.config.js           # PostCSS configuration (Tailwind preprocessor)
├── jest.config.js              # Jest testing framework configuration
├── tsconfig.json               # TypeScript configuration
├── .eslintrc.json              # ESLint linting rules
├── .prettierrc                 # Prettier code formatting rules
├── .env.local                  # Local environment variables (gitignored)
├── .env.example                # Example environment variables (template)
├── .gitignore                  # Git ignore patterns
├── README.md                   # Main project documentation
│
├── Git Hooks & CI/CD
├── .husky/                     # Husky git hooks directory
│   ├── pre-commit              # Pre-commit validation (lint + test)
│   ├── pre-push                # Pre-push validation (protected branches)
│   └── commit-msg              # Commit message validation (conventional commits)
├── .github/                    # GitHub Automation (Epics 3-6 - planned)
│   └── workflows/
│       ├── pr-validation.yml   # PR checks (lint, test, changelog preview)
│       └── release.yml         # Release automation (version, changelog, docs)
│
├── Database Schema & Migrations
├── prisma/
│   ├── schema.prisma           # Prisma schema definition (SiteProfile, Run, Metrics models)
│   └── migrations/             # Database migration history
│
├── Source Code
├── src/
│   ├── Entry Points
│   ├── middleware.js           # Next.js middleware (auth route protection)
│   │
│   ├── Frontend Layer (Next.js App Router)
│   ├── app/
│   │   ├── globals.css         # Global styles (Tailwind base)
│   │   ├── layout.tsx          # Root layout (HTML shell, providers)
│   │   ├── page.tsx            # Home/landing page
│   │   ├── (auth)/             # Route group (auth-related pages)
│   │   ├── dashboard/          # Main application pages
│   │   │   ├── page.tsx        # Dashboard home
│   │   │   ├── profiles/       # Site profile management
│   │   │   ├── runs/           # Automation run history
│   │   │   └── metrics/        # Analytics and metrics
│   │   └── api/                # API Routes (REST endpoints)
│   │       ├── profiles/
│   │       │   ├── route.ts    # GET/POST /api/profiles
│   │       │   └── [id]/
│   │       │       └── route.ts # GET/PUT/DELETE /api/profiles/[id]
│   │       ├── runs/
│   │       │   ├── route.ts    # GET/POST /api/runs
│   │       │   └── [id]/
│   │       │       └── route.ts # GET /api/runs/[id]
│   │       └── auth/           # Authentication endpoints
│   │
│   ├── CLI Layer (Orchestration)
│   ├── cli/
│   │   ├── automation.js       # 🎯 MAIN ENTRY POINT - Full pipeline orchestrator
│   │   ├── scraper.js          # Standalone scraper CLI
│   │   ├── processor.js        # Standalone processor CLI
│   │   ├── cleanup.js          # Cleanup utilities
│   │   └── db.js               # Database CLI commands (future)
│   │
│   ├── Core Business Logic (Services)
│   ├── core/
│   │   ├── scraper.js          # HTMLScraperService (Playwright scraping)
│   │   ├── processor.js        # ContentProcessorService (HTML sanitization)
│   │   ├── image-downloader.js # ImageDownloaderService (asset management)
│   │   └── csv-generator.js    # CSVGeneratorService (WordPress CSV export)
│   │
│   ├── React Components
│   ├── components/
│   │   ├── ui/                 # shadcn/ui primitives
│   │   │   ├── button.tsx
│   │   │   ├── card.tsx
│   │   │   ├── input.tsx
│   │   │   ├── dialog.tsx
│   │   │   └── ...             # Other shadcn components
│   │   ├── auth-button.jsx     # Authentication button component
│   │   └── [feature]/          # Feature-specific components (as needed)
│   │
│   ├── Shared Libraries (Framework Wrappers)
│   ├── lib/
│   │   ├── db/
│   │   │   └── client.ts       # Prisma Client singleton ⚠️ CRITICAL
│   │   ├── supabase/
│   │   │   ├── client.ts       # Supabase client (browser)
│   │   │   └── server.ts       # Supabase client (server)
│   │   └── utils.ts            # General utilities
│   │
│   ├── Shared Utilities (Pure Functions)
│   ├── utils/
│   │   ├── errors.js           # Custom error classes + retry logic
│   │   ├── filesystem.js       # File system operations
│   │   ├── cli.js              # CLI helpers (progress bars, tables)
│   │   └── date-helpers.js     # Date formatting utilities
│   │
│   ├── Configuration Management
│   ├── config/
│   │   └── index.js            # Singleton Config class ⚠️ CRITICAL
│   │
│   ├── Type Definitions
│   ├── types/
│   │   └── index.ts            # Shared TypeScript types
│   │
│   └── Background Services (Future)
│   └── services/
│       └── job-worker.js       # BullMQ worker process (async job execution)
│
├── Static Assets
├── public/
│   ├── images/                 # Public images (served from /images/...)
│   └── assets/                 # Other static assets
│
├── Data Files (Input Configuration)
├── data/
│   ├── urls.txt                # Target URLs for scraping
│   ├── custom-selectors.json   # Content type detection rules
│   └── url-mappings.json       # URL to WordPress slug mappings
│
├── Generated Content (Gitignored)
├── output/
│   ├── scraped-content/        # Raw HTML from scraper
│   ├── clean-content/          # Sanitized HTML
│   ├── images/                 # Downloaded images
│   └── wp-ready/               # WordPress import CSV files
│
├── Application Logs (Gitignored)
├── logs/
│   ├── combined.log            # All application logs
│   └── error.log               # Error logs only
│
├── BMAD Documentation & Workflows
├── _bmad-output/               # Generated documentation artifacts
│   ├── architecture.md         # This document
│   ├── development-guide.md    # Development setup and workflows
│   ├── technology-stack.md     # Technology stack details
│   ├── project-context.md      # AI agent implementation rules ⚠️ CRITICAL
│   ├── epics.md                # Epic and story breakdown
│   ├── sprint-status.yaml      # Sprint tracking
│   ├── stories/                # Individual story files
│   └── analysis/               # Analysis artifacts
├── _bmad/                      # BMAD framework files
│   └── bmm/
│       ├── config.yaml         # BMAD configuration
│       ├── workflows/          # Workflow definitions
│       └── agents/             # Agent personas
│
└── Tests (Not Yet Implemented)
└── tests/                      # Test directory (planned)
    ├── unit/                   # Unit tests
    ├── integration/            # Integration tests
    └── e2e/                    # End-to-end tests
```

### Architectural Boundaries

**API Boundaries:**

**External Boundaries (Public APIs):**

- **Next.js API Routes**: `/app/api/*` → RESTful HTTP/JSON APIs
  - `/api/profiles` - Site profile CRUD
  - `/api/runs` - Automation run management
  - `/api/auth` - Authentication endpoints
- **WordPress CSV Export**: Filesystem output (no API), consumed via manual import

**Internal Boundaries (Service Communication):**

- **CLI → Core Services**: Direct function calls (same Node.js process)
- **Web → Core Services**: Via BullMQ jobs (async) or direct calls (sync operations)
- **Worker → Core Services**: Direct calls in worker process context

**Component Boundaries:**

**Frontend Component Hierarchy:**

```
App Layout (layout.tsx)
  └─ Server Components (data fetching)
      └─ Client Components (interactivity)
          └─ shadcn UI Primitives (presentational)
```

**Component Communication Patterns:**

- **Server → Client**: Props (read-only data flow)
- **Client → Server**: Server Actions OR API route POST/PUT
- **Client → Client**: Props (parent-to-child) or Context (rare, avoid global state)

**Service Boundaries:**

**Service Layer Isolation:**

```
CLI Layer
  ↓ (instantiates)
Core Services (scraper, processor, image-downloader, csv-generator)
  ↓ (uses)
Utilities (errors, filesystem, cli helpers)
  ↓ (reads)
Configuration (singleton config)
```

**Service Communication:**

- **Service-to-Service**: Constructor dependency injection
- **Service-to-Utility**: Import and function call
- **Service-to-Config**: `config.get(section)`
- **Service-to-Database**: Via Prisma Client singleton (`@/lib/db/client`)

**Data Boundaries:**

**Database Access Layer:**

- **Prisma Client Singleton**: `src/lib/db/client.ts` → ONLY entry point to database
- **Schema**: `prisma/schema.prisma` → Single source of truth for data model
- **Migrations**: `prisma/migrations/` → Version-controlled schema history

**Data Flow Boundaries:**

```
External Website
  ↓ (Playwright)
HTMLScraperService → Raw HTML files (output/scraped-content/)
  ↓
ImageDownloaderService → Downloaded images (output/images/)
  ↓
ContentProcessorService → Sanitized HTML (output/clean-content/)
  ↓
CSVGeneratorService → WordPress CSV (output/wp-ready/)
  ↓
Manual Import → WordPress Database
```

**Alternative Flow (Web Dashboard):**

```
User Action (browser)
  ↓ (HTTP POST)
Next.js API Route
  ↓ (creates)
BullMQ Job → Redis Queue
  ↓ (worker picks up)
Job Worker Process
  ↓ (executes)
Core Services (same flow as CLI)
  ↓ (persists to)
Supabase PostgreSQL (via Prisma)
  ↓ (user polls)
GET /api/runs/[id] (status updates)
```

**Caching Boundaries:**

- **No Application Cache**: Redis dedicated to BullMQ only (no caching layer currently)
- **Browser Cache**: Next.js handles static asset caching automatically
- **Database Query Cache**: Prisma connection pooling only

### Requirements to Structure Mapping

**Epic 1: Local Development Quality Gates**

- **Stories**: All completed (Husky git hooks)
- **Location**: `.husky/` directory (pre-commit, pre-push, commit-msg hooks)
- **Dependencies**: `package.json` scripts, commitlint config

**Epic 2: Protected Branch Validation**

- **Stories**: 3 in review (docs validation, integration, emergency bypass)
- **Locations**:
  - `.husky/pre-push` - Protected branch enforcement
  - `scripts/validate-docs.js` - Documentation sync validation (planned)
- **Dependencies**: Epic 1 (hooks infrastructure)

**Epics 3-6: CI/CD Automation** (Planned)

- **Location**: `.github/workflows/` (GitHub Actions)
- **Stories**: 21 stories not yet created (per implementation readiness report)
- **Dependencies**: Epic 1-2 (local validation foundation)

**Core Platform Features** (Existing)

- **CLI Automation**: `src/cli/automation.js` + `src/core/*` services
- **Web Dashboard**: `src/app/dashboard/*` pages
- **Database Persistence**: `prisma/schema.prisma` + `src/lib/db/`
- **Job Queue**: `src/services/job-worker.js` (future)

### Cross-Cutting Concerns Mapping

**Authentication:**

- **Entry Point**: `src/middleware.js` (route protection)
- **Client Wrappers**: `src/lib/supabase/client.ts` (browser), `server.ts` (server)
- **Protected Routes**: `/dashboard/*` (enforced by middleware)
- **Database**: Supabase Auth schema (managed by Supabase)

**Logging:**

- **CLI Logging**: Winston (`src/utils/errors.js` initializes logger)
- **Log Files**: `logs/combined.log`, `logs/error.log` (gitignored)
- **Web Logging**: Console (TBD: external service like Sentry)

**Error Handling:**

- **Custom Errors**: `src/utils/errors.js` (ScraperError, ProcessingError, etc.)
- **Retry Logic**: `src/utils/errors.js` `retry()` function
- **Circuit Breaker**: Built into retry logic (stops after consecutive failures)

**Configuration:**

- **Singleton**: `src/config/index.js` ⚠️ ONLY config source
- **Environment Variables**: `.env.local` (overrides), `.env.example` (template)
- **Static Defaults**: Defined in `src/config/index.js` DEFAULTS object

**HTML Sanitization:**

- **Service**: `src/core/processor.js` `ContentProcessorService`
- **Whitelist Method**: `_shouldPreserveClass()` ⚠️ CRITICAL (Bootstrap preservation)
- **Rules**: Documented in `_bmad-output/project-context.md` Rule #1

### Integration Points

**Internal Communication:**

**CLI → Services:**

```javascript
// src/cli/automation.js
import { HTMLScraperService } from '../core/scraper.js';
const scraper = new HTMLScraperService(config.get('scraper'));
await scraper.scrapeUrls(urls);
```

**Web → Services (via Jobs):**

```javascript
// src/app/api/runs/route.ts
import { jobQueue } from '@/lib/bullmq';
await jobQueue.add('scrape', { profileId, urls });
```

**Services → Database:**

```javascript
// Any service
import { db } from '@/lib/db/client';
const profile = await db.siteProfile.findUnique({ where: { id } });
```

**External Integrations:**

**Playwright (Browser Automation):**

- **Integration Point**: `src/core/scraper.js` imports `playwright`
- **Browsers**: Chromium (headless Chrome)
- **Environment**: Requires browser binaries installed (`npm run install-browsers`)

**Supabase (Database + Auth):**

- **Database**: PostgreSQL connection via `DATABASE_URL` env var
- **Auth**: Supabase Auth API via `NEXT_PUBLIC_SUPABASE_URL` + keys
- **SDK**: `@supabase/supabase-js` + `@supabase/ssr` for Next.js

**Redis (Job Queue):**

- **Integration Point**: `src/services/job-worker.js` (future)
- **Library**: BullMQ (`bullmq` npm package)
- **Connection**: `REDIS_URL` env var

**WordPress (Target System):**

- **Integration**: CSV file export (manual import via Really Simple CSV Importer plugin)
- **Format**: Generated by `src/core/csv-generator.js`
- **No Direct API**: Offline integration via filesystem

**Data Flow:**

**CLI Execution Flow:**

```
User runs: npm start
  ↓
CLI Entry: src/cli/automation.js
  ↓ (instantiates with config)
HTMLScraperService (Playwright → websites)
  ↓ (writes raw HTML files)
ImageDownloaderService (downloads images)
  ↓ (updates image paths)
ContentProcessorService (JSDOM sanitization)
  ↓ (generates clean HTML)
CSVGeneratorService (packages for WordPress)
  ↓ (writes to filesystem)
Output: output/wp-ready/wordpress-import.csv
```

**Web Dashboard Flow:**

```
User visits: https://app.example.com/dashboard
  ↓ (Next.js middleware checks)
Supabase Auth (session validation)
  ↓ (if authenticated)
Server Component fetches data
  ↓ (via Prisma)
Supabase PostgreSQL
  ↓ (renders)
Client receives HTML + minimal JS
  ↓ (user triggers scrape)
POST /api/runs (creates job)
  ↓ (enqueues to)
Redis (BullMQ queue)
  ↓ (worker picks up)
Job Worker executes core services
  ↓ (stores results)
PostgreSQL (run status, metrics)
  ↓ (user polls)
GET /api/runs/[id] (status updates)
```

### File Organization Patterns

**Configuration Files:**

**Root Level Config:**

- **package.json**: Dependencies, scripts, project metadata
- **next.config.js**: Next.js build and runtime config
- **tailwind.config.js**: Design system tokens, theme configuration
- **tsconfig.json**: TypeScript compiler options (strict mode)
- **.eslintrc.json**: Linting rules (Airbnb base + Next.js plugin)
- **jest.config.js**: Test framework configuration (when tests implemented)

**Environment Files:**

- **.env.local**: Local env vars (gitignored, developer-specific)
- **.env.example**: Template with all required vars documented

**Prisma Config:**

- **prisma/schema.prisma**: Database schema definition (single file)

**Source Organization:**

**Layered Architecture:**

1. **Entry Points**: `src/app/` (Next.js), `src/cli/automation.js` (CLI)
2. **Business Logic**: `src/core/` (services)
3. **Shared Libraries**: `src/lib/` (framework wrappers)
4. **Utilities**: `src/utils/` (pure functions)
5. **Configuration**: `src/config/` (singleton)

**Feature Organization (Web):**

- **Pages**: `src/app/dashboard/[feature]/page.tsx`
- **Layouts**: `src/app/dashboard/[feature]/layout.tsx` (shared UI)
- **Components**: Co-located in page directory or `src/components/[feature]/`

**Test Organization** (Not Yet Implemented):

**Pattern (when implemented):**

- **Co-located**: `ComponentName.test.tsx` next to `ComponentName.tsx`
- **Alternative**: `tests/` directory mirroring `src/` structure
- **Naming**: `*.test.ts`, `*.spec.ts`, `*.test.tsx`

**Asset Organization:**

**Static Assets:**

- **Public Images**: `/public/images/` → served from `/images/...`
- **Dynamic Content**: `output/images/` → WordPress upload structure (gitignored)

**Logs:**

- **Winston Logs**: `logs/combined.log`, `logs/error.log` (gitignored)
- **Rotation**: Not configured (manual cleanup or future log rotation)

### Development Workflow Integration

**Development Server Structure:**

**Web Dashboard Development:**

```bash
npm run dev:web  # Starts Next.js on localhost:3000
```

- **Hot Reload**: Changes to `src/app`, `src/components` auto-reload
- **API Routes**: Accessible at `http://localhost:3000/api/*`
- **Database**: Requires `DATABASE_URL` in `.env.local`

**CLI Development:**

```bash
npm start  # Runs src/cli/automation.js
```

- **No Hot Reload**: Restart manually after code changes
- **Output**: Files written to `output/` directory
- **Logging**: Winston logs to `logs/` directory

**Database Development:**

```bash
npm run db:migrate  # Apply Prisma migrations
npm run db:studio   # Open Prisma Studio (visual DB editor)
```

**Build Process Structure:**

**Web Dashboard Build:**

```bash
npm run build  # Next.js production build
```

- **Output**: `.next/` directory (optimized bundles)
- **Static Generation**: Pre-renders pages at build time
- **Image Optimization**: Next.js Image component generates optimized variants

**CLI Build:**

- **No Build Step**: Direct Node.js execution (`"type": "module"`)

**Deployment Structure:**

**Web Dashboard Deployment:**

- **Platform**: Vercel (recommended) or Next.js-compatible host
- **Environment Variables**: Set in platform dashboard (DATABASE*URL, SUPABASE*\*, REDIS_URL)
- **Build Command**: `npm run build`
- **Start Command**: `npm start` (Next.js server)

**Worker Deployment:**

- **Same Platform**: Deploy worker as separate process or serverless function
- **Entry Point**: `src/services/job-worker.js`
- **Shared Code**: Worker uses same `src/core` services as CLI

**CLI Deployment:**

- **No Hosting**: Runs locally or in CI/CD runner
- **Distribution**: npm package (future consideration)
