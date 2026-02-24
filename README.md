# Content Automation Pipeline

A robust, enterprise-grade content automation system that scrapes web content and prepares it for WordPress import. Built with modern JavaScript and designed for scalability, maintainability, and ease of use.

## Overview

### Business Need

Content bulk migration from competitor websites to WordPress is a time-consuming, manual process that requires:

- Extracting content from multiple pages and posts
- Downloading and adding images with proper paths
- Converting internal links to WordPress-friendly URLs
- Classifying content as posts or pages

This system automates the majority of the pipeline, reducing manual work from ~15 minutes~ per page to automated batch processing. Originally built for automotive dealership websites, the system is extensible to other industries and website structures.

### What This System Does

The Content Automation Pipeline provides:

- **Web Scraping**: Extracts content from websites using Playwright, handling modern JavaScript, Cloudflare protection, and dynamic content
- **Content Processing**: Aggressively cleans HTML, removes unwanted elements, and preserves essential formatting
- **Image Management**: Downloads images concurrently, organizes them with WordPress-friendly paths, and updates references in content
- **Content Classification**: Automatically detects whether content is a blog post or static page - current version requires explicit list of blog post urls or page urls for simplicity in UI
- **WordPress Integration**: Generates CSV files compatible with Really Simple CSV Importer plugin
- **Web Dashboard**: Modern Next.js interface for managing runs, configurations, and tracking metrics via postgresql database hosted on Supabase
- **Multi-User Support**: Secure authentication with Supabase Auth for team collaboration and user metrics

### Key Features

#### Core Automation Features

- **Robust Web Scraping**: Uses Playwright to handle modern websites, Cloudflare protection, and JavaScript-heavy content
- **Intelligent Content Cleaning**: Removes unwanted attributes, classes, and IDs while preserving essential formatting
- **Custom Element Removal**: Interactive configuration for CSS selectors to remove during sanitization
- **Smart Link Processing**: Converts internal links to WordPress-friendly URLs with custom mapping
- **Image Management**: Downloads and organizes images with proper WordPress paths
- **CSV Generation**: Creates WordPress-ready CSV files for Really Simple CSV Importer
- **Blog Content Cleanup**: Removes navigation, dates, and sidebar content that WordPress generates automatically, keeps posted date for blogs consistent with imported posts

#### Web Dashboard Features

- **User Management**: Secure authentication with Supabase Auth
- **Site Profiles**: Save and reuse configuration profiles for different competitor site types
- **Run Management**: Start, monitor, and track automation runs with real-time progress
- **Metrics Dashboard**: View statistics including time saved, URLs scraped, success rates
- **Download Management**: Automatic saving to Desktop/Content-Migration folder plus direct CSV downloads
- **Structured Logging**: Database-backed logs for debugging and auditing

## Quick Start

Install ImageMagick (optional but recommended):
ImageMagick enables automatic AVIF → JPEG image conversion for WordPress compatibility.

macOS:

```bash
brew install imagemagick
```
Verify installation:

```bash
convert -version
```
Note: The system works without ImageMagick but will skip AVIF image conversion. You'll see a warning if AVIF images are encountered.

```bash
git clone https://github.com/rvandehey-cc/content-automation.git
cd content-automation
bash setup.sh
```

That's it. The setup script handles everything:
- Installs Homebrew, Node.js (20.9+ required for Next.js), and dependencies
- Generates Prisma client and installs Playwright browsers
- Creates `.env` with database credentials (fetched automatically or prompted)
- Configures shell PATH and aliases
- Validates the installation

Once complete, open http://localhost:3000 and sign up with your email.

### Running After Setup

```bash
npm run dev:web
```

Or use the global command (available after restarting terminal):
```bash
content-automation
```

## Using the Web Dashboard

### First-Time Setup

1. **Create an account:**
   - Navigate to http://localhost:3000/auth/signup
   - Enter your email and password
   - If email confirmation is enabled in Supabase, check your email and click the confirmation link
   - If disabled for development, you'll be logged in immediately

2. **Create a Site Profile:**

Note: This is not always needed, but can be helpful if competitor site has elements that need to be manually identified for removal. Try one post/page test run first or select an existing profile based on the competitor site. (Dealer.com etc.)

- Click "Site Profiles" in the navigation
- Click "Create New Profile"
- Enter a name and description for your site
- Configure scraping settings:
  - Content selectors (CSS selectors to find main content)
  - Blog post selectors (for date, title, content extraction)
  - Custom remove selectors (elements to exclude during cleaning)
  - WordPress settings (dealer slug, image year/month)
  - Image processing settings
- Click "Save Profile"

### Starting an Automation Run

1. **Navigate to Runs:**
   - Click "Runs" in the navigation
   - Click "Start New Run"

2. **Configure the run:**
   - **Select Site Profile** (optional): Choose a saved profile to load its configuration
   - **Enter URLs**: Paste URLs to scrape, one per line
   - **Content Type**: Select "Post" for blog articles or "Page" for static pages
   - **Blog Post Selectors** (if content type is "Post"):
     - Date selector: CSS selector to find publication date - automatic detection usually works
     - Content selector: CSS selector to find main content -
       automatic detection usually works
   - **Custom Remove Selectors**: CSS selectors for elements to remove during cleaning (one per line), may be needed depending on site type and structure.
   - **WordPress Settings**:
     - Dealer slug: Used in image paths
   - **Image Processing**: Toggle to enable/disable image downloading

3. **Start the run:**
   - Click "Start Run"
   - The run will be created and execution will begin automatically
   - You'll be redirected to the run detail page
4. **Importing Content to WP**
   - In WP admin enable Really Simple CSV Importer plugin
   - Upload downloaded images to media gallery and input alt text
   - Tools > Import > Really Simple CSV Importer plugin > select generated csv file
   - Audit posts and pages for accuracy, published status, and user

### Monitoring Runs

1. **View run list:**
   - Navigate to "Runs" to see all runs
   - Runs show status (pending, running, completed, failed), creation date, and basic metrics

2. **View run details:**
   - Click on any run to see detailed information
   - **Overview**: Status, timestamps, configuration snapshot
   - **Metrics**: URLs scraped, images downloaded, files processed, success rates
   - **Progress**: Real-time progress updates during execution
   - **Download CSV**: Download the generated WordPress import file

3. **View metrics dashboard:**
   - Navigate to "Metrics" to see aggregated statistics
   - View total runs, URLs processed, time saved calculations
   - See breakdown by site profile

### Managing Site Profiles

1. **Create profiles:**
   - Navigate to "Site Profiles"
   - Click "Create New Profile"
   - Configure all settings and save

2. **Edit profiles:**
   - Click on a profile to view details
   - Click "Edit" to modify configuration
   - Changes are saved immediately

3. **Use profiles:**
   - When starting a new run, select a profile from the dropdown
   - Profile settings will populate the form
   - You can override any setting manually if needed

### Output Files

When a run completes, files are automatically organized by dealer:

- **CSV Files**: `~/Desktop/Content-Migration/{dealer-slug}/csv/wordpress-import-YYYY-MM-DD.csv`
- **Images**: `~/Desktop/Content-Migration/{dealer-slug}/images/YYYY-MM-DD/`

The `dealer-slug` is:

- **From Site Profile**: If configured in the site profile's "Dealer Slug" field
- **Auto-detected**: Extracted from the website domain (e.g., `www.zimbricknissan.com` → `zimbricknissan`)
- **Fallback**: Uses `unknown-dealer` if detection fails

**Benefits of Dealer-Based Organization:**

- Easily identify which dealer's content is in each folder
- Multiple runs for the same dealer are organized together
- CSV files include dates to prevent overwrites
- Images are organized in dated subfolders for easy management

You can also download CSV files directly from the run detail page.

## How It Works

### Architecture Overview

The system follows a service-based architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    Web Dashboard (Next.js)                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Site       │  │     Runs     │  │   Metrics    │     │
│  │  Profiles    │  │  Management  │  │  Dashboard   │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
├─────────────────────────────────────────────────────────────┤
│                    API Layer (Next.js API Routes)          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  Site        │  │     Runs     │  │   Metrics    │     │
│  │  Profiles    │  │     API      │  │     API      │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
├─────────────────────────────────────────────────────────────┤
│                    Service Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Run        │  │   HTML       │  │   Content   │     │
│  │  Executor    │  │   Scraper    │  │  Processor   │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐  ┌──────────────┐                       │
│  │   Image      │  │     CSV      │                       │
│  │  Downloader  │  │  Generator   │                       │
│  └──────────────┘  └──────────────┘                       │
├─────────────────────────────────────────────────────────────┤
│                    Data Layer                                │
│  ┌──────────────┐  ┌──────────────┐                       │
│  │   Prisma     │  │   Supabase   │                       │
│  │    ORM       │  │     Auth     │                       │
│  └──────────────┘  └──────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

### Workflow Pipeline

1. **User creates a run** via the web dashboard
2. **Run executor service** orchestrates the automation:
   - Updates run status in database
   - Logs progress and errors
3. **HTML Scraper Service** extracts content:
   - Uses Playwright for headless browsing
   - Handles Cloudflare protection
   - Extracts content using CSS selectors
   - Implements retry logic with exponential backoff
4. **Image Downloader Service** (if enabled):
   - Extracts image URLs from HTML
   - Downloads images concurrently with rate limiting
   - Organizes images with WordPress-friendly structure
   - Creates mapping files for URL updates
5. **Content Processor Service** sanitizes HTML:
   - Removes ALL classes and IDs (aggressive cleaning)
   - Preserves essential attributes (style, href, src)
   - Updates internal links to WordPress-friendly URLs
   - Removes blog-specific elements (navigation, dates, sidebar)
   - Fixes malformed HTML tags
6. **CSV Generator Service** creates WordPress import file:
   - Detects content type (post vs page) or uses explicit selection
   - Generates WordPress slugs from URLs
   - Sets post dates (pages use yesterday's date for immediate publication)
   - Formats CSV compatible with Really Simple CSV Importer

### Content Processing Details

#### Aggressive Cleaning Strategy

The processor implements an aggressive cleaning approach optimized for WordPress:

**Removes:**

- ALL `class` and `id` attributes
- Third-party tracking attributes
- Blog template elements (navigation, dates, sidebar)
- Footer content and copyright notices
- Forms and interactive elements
- Testimonial blocks (for posts)
- Custom user-specified elements (via CSS selectors)

**Preserves:**

- `style` attributes for formatting
- Essential link attributes (`href`, `target`)
- Image attributes (`src`, `alt`, `width`, `height`)
- Table structure attributes

**Content Type Detection:**

- Uses explicit user selection (from UI) when available
- Falls back to automatic detection using:
  - URL patterns (blog, post, article keywords)
  - CSS class analysis (post-navigation, page-header, etc.)
  - Content structure analysis

**Date Handling:**

- **Posts**: Extracts original publication date from article if available, otherwise uses current date
- **Pages**: Uses yesterday's date to ensure immediate publication (avoids WordPress scheduling)

### Database Schema

The system uses Prisma ORM with PostgreSQL (Supabase) for data persistence:

- **SiteProfile**: Configuration profiles for different sites/dealers
- **Run**: Job/run tracking with status and metadata
- **RunMetrics**: Metrics collected during runs (success rates, counts, etc.)
- **LogEntry**: Structured log entries with filtering capabilities
- **ContentPreview**: Preview storage for scraped and processed content

See `prisma/schema.prisma` for complete schema definition.

### Authentication

The system uses Supabase Auth for secure multi-user access:

- Email/password authentication
- Session management via HTTP-only cookies
- Protected API routes require valid authentication
- Middleware automatically redirects unauthenticated users to login

## Development Setup

```bash
git clone https://github.com/rvandehey-cc/content-automation.git
cd content-automation
bash setup.sh
```

The setup script installs all prerequisites, dependencies, and configures credentials automatically.

> **Note:** Redis/Docker is only needed for advanced job queue features. The system works fine without it for basic content automation.

### Development Commands

```bash
# Web Dashboard
npm run dev:web   # Start Next.js dev server
npm run build     # Build for production
npm run start:web # Start production server
npm run lint:web  # Lint Next.js code

# Database
npm run db:generate      # Generate Prisma Client (required)
npm run db:migrate       # Run migrations (only needed if you're developing schema changes)
npm run db:studio        # Open Prisma Studio (database GUI)
npm run db:migrate:reset # Reset database (only for local development/schema changes)

# CLI (Legacy)
npm start       # Run full automation pipeline
npm run scrape  # Run scraper only
npm run process # Run processor only
npm run clean   # Clear output directories

# Testing
npm test              # Run test suite
npm run test:watch    # Run tests in watch mode
npm run test:coverage # Generate coverage report
```

### Project Structure

```
wp-content-automation/
├── src/
│   ├── app/                    # Next.js web dashboard
│   │   ├── api/                # API routes
│   │   │   ├── runs/           # Run management API
│   │   │   ├── site-profiles/  # Site profile API
│   │   │   ├── metrics/        # Metrics API
│   │   │   └── auth/           # Authentication API
│   │   ├── runs/               # Run management pages
│   │   ├── site-profiles/      # Site profile pages
│   │   ├── metrics/            # Metrics dashboard
│   │   └── auth/               # Authentication pages
│   ├── cli/                    # Command-line interfaces (legacy)
│   │   ├── automation.js       # Main pipeline orchestrator
│   │   └── cleanup.js          # Maintenance utilities
│   ├── core/                   # Business logic services
│   │   ├── scraper.js          # Web scraping service
│   │   ├── processor.js        # Content processing service
│   │   ├── csv-generator.js    # WordPress CSV generation
│   │   └── image-downloader.js # Image asset management
│   ├── services/               # Service layer
│   │   └── run-executor.js    # Orchestrates automation runs
│   ├── lib/                    # Shared libraries
│   │   ├── db/                 # Prisma database client
│   │   ├── supabase/           # Supabase client
│   │   └── utils.ts            # Utility functions
│   ├── components/             # React components
│   │   ├── ui/                 # shadcn/ui components
│   │   └── auth-button.jsx    # Authentication component
│   ├── config/                 # Configuration management
│   │   └── index.js            # Centralized configuration
│   ├── utils/                  # Shared utilities
│   │   ├── cli.js              # Command-line interface helpers
│   │   ├── errors.js           # Error handling and retry logic
│   │   ├── filesystem.js       # File system operations
│   │   └── content-migration-path.js  # Content-Migration folder management
│   └── middleware.js           # Next.js middleware for auth
├── prisma/                     # Database schema and migrations
│   ├── schema.prisma           # Prisma schema definition
│   └── migrations/             # Database migration files
├── data/                       # Configuration and input data
│   ├── urls.txt               # URLs to scrape (CLI mode)
│   └── custom-selectors.json  # Content type detection rules
├── output/                     # Generated content (gitignored)
│   ├── scraped-content/       # Raw HTML from scraper
│   ├── clean-content/         # Processed HTML
│   ├── images/                # Downloaded images
│   └── wp-ready/              # WordPress import files
└── docker-compose.yml          # Docker services configuration
```

### Code Standards

- **ES6+ modules** with async/await
- **JSDoc documentation** standards
- **Service-based architecture** with dependency injection
- **Configuration-driven behavior**
- **Comprehensive error handling** with retry mechanisms
- **TypeScript-style JSDoc** for better IDE support

### Architecture Guidelines

- Keep services focused and single-purpose
- Use dependency injection for testability
- Prefer composition over inheritance
- Implement proper separation of concerns
- Use configuration objects over hardcoded values

## Configuration

### Environment Variables

See the [Quick Start](#quick-start) section for required environment variables.

### Site Profile Configuration

Site profiles store reusable configuration for different websites:

- **Scraper Settings**: Content selectors, wait times, timeouts, retry counts
- **Blog Post Settings**: Date selector, content selector, title selector, exclude selectors
- **Page Settings**: Content selector, exclude selectors
- **Processor Settings**: Custom remove selectors, class/ID removal options
- **Image Settings**: Enable/disable, max concurrent downloads
- **WordPress Settings**: Dealer slug, image year/month

### Content Type Selection

The system supports explicit content type selection:

- **Post/Blog**: User selects "Post" in UI → content is always classified as post
- **Page**: User selects "Page" in UI → content is always classified as page
- **Automatic**: If no explicit selection, system uses detection algorithms

## Troubleshooting

### Web Dashboard Issues

**"Database connection failed"**

- Verify `DATABASE_URL` in `.env` is correct
- Ensure Supabase project is active (not paused)
- Check network connectivity to Supabase
- Run `npm run db:generate` to regenerate Prisma Client

**"Authentication not working"**

- Verify `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` in `.env`
- Check Supabase Auth settings (email confirmation may need to be disabled for dev)
- Clear browser cookies and try again
- Check browser console for errors

**"Run not found" errors**

- Ensure database migrations are up to date: `npm run db:migrate`
- Check that run was created successfully in database
- Verify user has permission to view the run

**"CSV download fails"**

- Check that CSV file exists in `output/wp-ready/`
- Verify file permissions
- Check server logs for errors
- Ensure Content-Migration folder exists and is writable

**"Content-Migration folder not created"**

- Check file system permissions
- Verify `CONTENT_MIGRATION_PATH` if using custom path
- Ensure parent directory exists

### CLI Issues

**"No URLs to scrape"**

- Check `data/urls.txt` exists and contains valid URLs
- Ensure URLs are one per line with no extra spaces

**"Cloudflare blocked request"**

- System includes bypass techniques
- Reduce concurrency or add delays if persistent
- Check if site requires additional anti-bot measures

**"Content type detection incorrect"**

- Review custom selectors in site profile or CLI setup
- Use browser dev tools to find unique class names
- Update selectors in site profile configuration

**"Images not downloading"**

- Verify images are enabled in configuration
- Check network connectivity
- Review image download logs for specific errors
- Consider using bypass images option if issues persist

## Additional Documentation

- **[QUICK_START.md](./QUICK_START.md)**: Quick start guide for new developers
- **[AUTH_SETUP.md](./AUTH_SETUP.md)**: Detailed Supabase authentication setup
- **[DATABASE_SETUP.md](./DATABASE_SETUP.md)**: Database setup instructions
- **[DOCKER_CONTENT_MIGRATION.md](./DOCKER_CONTENT_MIGRATION.md)**: Docker setup for Content-Migration folder
- **[DEVELOPMENT_STATUS.md](./DEVELOPMENT_STATUS.md)**: Development status tracking

## Contributing

### Submitting Changes

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Update documentation
5. Submit a pull request

### Quality Gates

This project uses automated git hooks to enforce code quality:

- **Pre-commit**: Linting and unit tests run before each commit
- **Pre-push**: Full test suite with coverage and documentation validation before pushing to main/dev
- **Commit messages**: Conventional commit format is enforced

**Emergency Bypass:** In genuine emergency situations (critical production hotfixes, security vulnerabilities), you can bypass git hooks using the `--no-verify` flag. See [docs/development-guide.md](./docs/development-guide.md#emergency-bypass) for detailed guidelines on when and how to use this capability responsibly.

### Testing Strategy

- Unit tests for core business logic
- Integration tests for service interactions
- End-to-end tests for complete workflows
- Mock external dependencies appropriately

## Environment Variables Reference

For your convenience, here's a template `.env.example` file you can create:

```env
# Supabase Configuration
# Database URL - Replace with your Supabase PostgreSQL connection string
DATABASE_URL="postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres"

# Supabase Public Keys - Replace with your project credentials
NEXT_PUBLIC_SUPABASE_URL=https://[PROJECT-REF].supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=[YOUR-ANON-KEY]

# Optional: Application Configuration
# NODE_ENV=development
# NEXT_PUBLIC_APP_URL=http://localhost:3000

# Optional: Redis Configuration (for advanced job queue features)
# REDIS_URL="redis://localhost:6379"
# REDIS_PORT=6379
```

> **Note:** Only the Supabase configuration is required. Redis and other optional settings are for advanced features.

## Expansion & Customization

This system was originally built for automotive dealership websites but is designed to be extensible:

### Customization Points

- **Link patterns**: Currently optimized for automotive URLs (new, used, service, parts)
- **Content detection**: Uses dealership-specific selectors
- **Cleanup patterns**: Targets common dealership CMS elements

### Requires Customization For

- Different dealer groups (GM, Toyota, Honda, etc.)
- Non-automotive industries
- Different CMS platforms
- Custom URL structures

### Extension Points

- `src/core/processor.js`: Link mapping and cleanup rules
- `src/core/csv-generator.js`: Content type detection logic
- `src/config/index.js`: Default configuration values
- Site profiles: Store custom configurations per site

## License

MIT

---

**Built for the modern web** | **Enterprise-ready** | **Highly customizable**

> **Version 2.0.0** - Web Dashboard, Database Integration, and Docker Support
