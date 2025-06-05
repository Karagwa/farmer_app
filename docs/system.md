Project Overview
Purpose and Goals
HPGM is a comprehensive Flutter application designed for beekeepers to monitor and optimize hive productivity. The primary goals of the application are to:

Provide real-time monitoring of bee activity through video analysis
Track environmental conditions that affect hive health and productivity
Generate actionable insights based on collected data
Streamline the record-keeping process for beekeepers
Improve honey production through data-driven decision making
Target Users
Professional beekeepers managing multiple apiaries
Hobbyist beekeepers looking to optimize their beekeeping practices
Agricultural researchers studying bee behavior and productivity
Apiculture educators and students
Key Differentiators
Advanced video analysis for bee counting without physical hive manipulation
Comprehensive data collection combining environmental factors with bee activity
AI-powered recommendations tailored to specific apiaries and conditions
Cross-platform availability ensuring access on any device
farmer_app/
├── android/                  # Android-specific configuration
├── assets/                   # Images, fonts, and other static resources
│   ├── images/               # Application images and icons
│   ├── fonts/                # Custom fonts
│   └── data/                 # Static data files for reference
├── docs/                     # Documentation files
│   ├── api/                  # API documentation
│   ├── architecture/         # Architecture diagrams and explanations
│   └── system.md             # System documentation (this file)
├── ios/                      # iOS-specific configuration
├── lib/                      # Dart source code
│   ├── analytics/            # Analytics and data processing
│   │   ├── foraging_analysis/  # Foraging pattern analysis
│   │   ├── hive_performance/   # Hive performance metrics
│   │   └── recommendations/    # Recommendation generation
│   ├── api/                  # API clients and services
│   │   ├── backend/          # Backend API integration
│   │   ├── weather/          # Weather API integration
│   │   └── analytics/        # Analytics API integration
│   ├── bee_counter/          # Bee counting and monitoring functionality
│   │   ├── video/            # Video processing components
│   │   ├── analysis/         # Analysis algorithms
│   │   └── reporting/        # Report generation
│   ├── models/               # Data models
│   │   ├── bee_count.dart    # Bee count model
│   │   ├── farm.dart         # Farm/apiary model
│   │   ├── hive.dart         # Hive model
│   │   └── user.dart         # User model
│   ├── screens/              # Application screens
│   │   ├── apiary/           # Apiary management screens
│   │   ├── hive/             # Hive management screens
│   │   ├── analysis/         # Analysis and reporting screens
│   │   └── settings/         # Settings and configuration screens
│   ├── Services/             # Application services
│   │   ├── auth/             # Authentication services
│   │   ├── storage/          # Data storage services
│   │   ├── sync/             # Data synchronization services
│   │   └── notifications/    # Notification services
│   ├── utils/                # Utility functions and helpers
│   │   ├── formatters/       # Data formatters
│   │   ├── validators/       # Input validators
│   │   └── helpers/          # General helper functions
│   ├── widgets/              # Reusable UI components
│   │   ├── charts/           # Chart and graph widgets
│   │   ├── forms/            # Form components
│   │   └── common/           # Common UI elements
│   ├── config/               # Application configuration
│   ├── themes/               # UI themes and styles
│   ├── localization/         # Localization resources
│   ├── routes.dart           # Application routes
│   └── main.dart             # Application entry point
├── linux/                    # Linux-specific configuration
├── macos/                    # macOS-specific configuration
├── web/                      # Web-specific configuration
├── windows/                  # Windows-specific configuration
├── test/                     # Test files
│   ├── unit/                 # Unit tests
│   ├── widget/               # Widget tests
│   └── integration/          # Integration tests
├── pubspec.yaml              # Dependencies and app metadata
└── README.md                 # Project README


Architecture
System Architecture Overview
HPGM follows a layered architecture pattern to ensure separation of concerns and maintainability. The architecture is designed to support the cross-platform nature of Flutter while optimizing for performance and scalability.

Architectural Diagram
```
┌───────────────────────────────────────────────────────────┐
│                   Presentation Layer                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐    │
│  │   Screens   │  │   Widgets   │  │ UI Components   │    │
│  └─────────────┘  └─────────────┘  └─────────────────┘    │
└───────────────────────────────────────────────────────────┘
                           ▲
                           │
                           ▼
┌───────────────────────────────────────────────────────────┐
│                  Business Logic Layer                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐    │
│  │  Services   │  │ Controllers │  │ State Management│    │
│  └─────────────┘  └─────────────┘  └─────────────────┘    │
└───────────────────────────────────────────────────────────┘
                           ▲
                           │
                           ▼
┌───────────────────────────────────────────────────────────┐
│                      Data Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐    │
│  │   Models    │  │Repositories │  │  Data Sources   │    │
│  └─────────────┘  └─────────────┘  └─────────────────┘    │
└───────────────────────────────────────────────────────────┘
                           ▲
                           │
                           ▼
┌───────────────────────────────────────────────────────────┐
│                 Infrastructure Layer                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐    │
│  │ Local DB    │  │  Network    │  │ Platform Services│   │
│  └─────────────┘  └─────────────┘  └─────────────────┘    │
└───────────────────────────────────────────────────────────┘
```

Presentation Layer
The presentation layer handles all UI components and user interactions. It consists of:

Screens: Complete application screens corresponding to different features
Widgets: Reusable UI components that make up screens
UI Components: Small, atomic UI elements used to build widgets
The presentation layer follows these principles:

Stateless widgets for UI representation wherever possible
Stateful widgets only when necessary for local state management
Separation of UI logic from business logic
Responsive design for multi-platform support
Business Logic Layer
The business logic layer contains all application logic and coordinates data flow between the presentation and data layers. It consists of:

Services: Encapsulate core business logic and operations
Controllers: Coordinate between UI and services
State Management: Manage application state using Provider pattern and streams
Key services include:

ApiaryService: Manages apiaries and hives
BeeCounterService: Handles bee counting and video analysis
AnalyticsService: Processes data for insights and recommendations
ReportService: Generates PDF reports
Data Layer
The data layer handles all data operations including validation, transformation, and persistence. It consists of:

Models: Data structures representing application entities
Repositories: Provide an abstraction over data sources
Data Sources: Handle direct data access (local DB, network, etc.)
Each model class includes:

Data validation logic
Serialization/deserialization methods
Business logic specific to the entity
Infrastructure Layer
The infrastructure layer provides platform-specific implementations and interfaces with external systems. It consists of:

Local DB: SQLite implementation using sqflite package
Network: HTTP client and API communication
Platform Services: Camera, sensors, file system, etc.