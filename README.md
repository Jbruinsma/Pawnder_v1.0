**PAWNDER | PROJECT OVERVIEW**

Pawnder is a mobile platform designed to fight pet-owner isolation 
by centralizing communities into a single, high-engagement hub. 


Pawnder is built to implement a spatial data 
model that balances location relevance with community accuracy. The platform 
serves as a digital neighborhood safety net. It addresses 
the systemic issues of low engagement and animal welfare visibility by 
transforming passive neighborhoods into active, supportive ecosystems.


**PAWNDER | DATABASE SETUP & CONFIGURATION**

Pawnder utilizes PostgreSQL with specific extensions for geospatial matching, 
unique identifiers, and fuzzy search functionality. Ensure the following 
steps are completed in order to avoid backend runtime errors.

1. INSTALLATION (POSTGRESQL & POSTGIS)
A local instance of PostgreSQL (v14 or higher) and the PostGIS spatial 
extension are required.

[ Windows ]
  1. Download the installer: https://www.enterprisedb.com/downloads/postgres-postgresql-downloads
  2. Ensure "Stack Builder" is selected during installation.
  3. Post-installation, launch Stack Builder, select your server, and install 
     the PostGIS bundle under the 'Spatial Extensions' category.
  
[ macOS ]
  - Install Postgres.app: https://postgresapp.com/ (includes PostGIS by default).
  - Alternatively, use Homebrew: brew install postgis.

[ Linux (Ubuntu) ]
  - $ sudo apt update && sudo apt install postgresql postgresql-contrib postgis

2. DATABASE INITIALIZATION
Create the project database via terminal, PowerShell, or pgAdmin:

  CREATE DATABASE pawnder_db;

3. EXTENSION CONFIGURATION (REQUIRED)
The following extensions must be manually enabled within 'pawnder_db' to 
support the application's core data types:

  \c pawnder_db;

  -- Support for UUID primary keys
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

  -- Support for geospatial logic and location matching
  CREATE EXTENSION IF NOT EXISTS "postgis";

  -- Support for trigram indices and fuzzy search
  CREATE EXTENSION IF NOT EXISTS "pg_trgm";

4. AUTHENTICATION & CREDENTIALS
PostgreSQL defaults to the 'postgres' superuser. If you encounter role or 
authentication errors, verify your credentials.

Resetting the Password (if required):
  1. Access the prompt: $ sudo -u postgres psql
  2. Execute: ALTER USER postgres WITH PASSWORD 'your_password';
  3. Exit: \q

Verifying Active Roles:
  $ psql -U postgres -c "\du"

**PAWNDER | OBJECT STORAGE & INFRASTRUCTURE (OCI)**

Pawnder uses Oracle Cloud Infrastructure (OCI) Object Storage for storing images uploaded by users. You must configure an OCI bucket and 
API credentials to enable these features.

Orcacle offers a free tier for OCI Object Storage, which includes 20 GB of storage and 10 GB of outbound data transfer per month. This is more than enough for development and testing purposes.

1. BUCKET SETUP
A Standard Object Storage bucket is required to store application assets. 
Refer to the official Oracle documentation for step-by-step creation:
- Create a Bucket: https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/managingbuckets_topic-To_create_a_bucket.htm

*AFTER CREATING THE BUCKET, GO INTO THE BUCKET DETAILS AND SET THE BUCKET VISIBILITY TO 'Public Read'*

2. API AUTHENTICATION
To interface with OCI via the SDK, you must generate an API RSA key pair and 
upload the public key to your OCI User profile to obtain a fingerprint.
- API Key & Fingerprint Setup: https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm

**PAWNDER | BACKEND SETUP**

The Pawnder backend is built using Python 3.10+. It uses the FastAPI framework 
for high-performance API endpoints and SQLAlchemy for database storage.

1. PREREQUISITES
Make sure you have Python 3.10 or higher installed on your system. 

In the project directory, enter the backend folder:

  $ cd backend

Use a virtual environment to manage dependencies. Create and activate it using the following commands:

- Windows:

$ python -m venv venv

$ source venv/bin/activate

$ .\venv\Scripts\activate

- macOS/Linux:

$ python3 -m venv venv

$ source venv/bin/activate

2. DEPENDENCY INSTALLATION
Install the required Python packages listed in the requirements file:

  $ pip install -r requirements.txt

3. ENVIRONMENT CONFIGURATION (.env)

The application requires several environment variables to interface with 
the database and Oracle Cloud Infrastructure (OCI). 

Copy the provided '.env.example' to create your local environment file:

  $ cp .env.example .env

Open the '.env' file and populate the following fields with your specific 
credentials and configuration:

  - Database Connection: Set POSTGRES_USER, POSTGRES_PASSWORD, and the 
    matching DATABASE_URL.
  - Security: Generate a secure SECRET_KEY for session management.
  - OCI Integration: Provide your Tenancy OCID, User OCID, Fingerprint, 
    and the path to your OCI API key (e.g., ./secrets/oci_api_key.pem).
  - Storage: Specify the OCI_NAMESPACE and OCI_BUCKET names created in 
    the Infrastructure section.

4. RUNNING THE SERVER & AUTO-INITIALIZATION

Start the application using Uvicorn. Upon startup, the 'lifespan' event 
automatically triggers the creation of all database tables defined in the 
models.

  $ uvicorn main:app --reload

- API Access: http://localhost:8000
- API Documentation (Swagger): http://localhost:8000/docs

*Note: If the application fails to start, verify that the PostgreSQL 
extensions (Step 3 of Database Setup) were successfully enabled. The 
auto-initialization will fail if PostGIS or UUID-OSSP are missing.

**PAWNDER | FRONTEND SETUP (FLUTTER)**

The Pawnder mobile application is built using the Flutter framework, providing 
cross-platform support for Android and iOS.

1. PREREQUISITES & INSTALLATION
Before setting up the project, you must install the Flutter SDK and the 
appropriate platform tools (Android Studio for Android or Xcode for iOS).

Official Flutter Installation Guide: https://docs.flutter.dev/get-started/install.

Once installed, navigate to the frontend directory inside the project directory from the project root:
- $ cd frontend

verify your environment by running:
    
 - $ flutter doctor

2. DEPENDENCY MANAGEMENT
Navigate to the frontend directory and retrieve the required packages from 
the pub.dev registry:
    $ cd frontend
    $ flutter pub get

3. API CONFIGURATION
The frontend must be configured to point to your local FastAPI backend server. 
Locate the API Service file: *frontend/lib/services/api_client.dart*  
and update the base URL:

  - Android Emulator: http://10.0.2.2:8000/api/v1
  - iOS Simulator: http://localhost:8000/api/v1
  - Physical Device: Use your machine's local IP address (e.g., http://192.168.1.x:8000/api/v1)

4. RUNNING THE APPLICATION
Ensure an emulator is running or a physical device is connected via USB. 
Execute the following command to start the application:

  $ flutter run

To compile the application for testing in high-performance mode:
  $ flutter run --release

**PAWNDER | TESTING & QUALITY ASSURANCE**

Due to the rapid development cycle for the initial MVP, I used a manual functional testing strategy paired with PyTests 
for backend development. This involved systematic verification of core features across the full stack to ensure 
stability for the final demonstration.

1. TESTING METHODOLOGY
- Manual Integration Testing: Verifying that the Flutter frontend correctly 
  communicates with the FastAPI backend and handles JSON responses.
- End-to-End (E2E) Verification: Simulating a user journey from account 
  creation to pet discovery and image upload.
- Cross-Platform Verification: Testing the UI and performance on both Android 
  and iOS environments; Emmulators and physical devices.

2. SAMPLE TEST CASES & RESULTS

| Feature        | Test Case Description                    | Result |
|----------------|------------------------------------------|--------|
| Authentication | Register new user and login with JWT     | PASS   |
| Pet Discovery  | Fetch pet list within a 25-mile radius   | PASS   |
| Image Upload   | Upload pet photo to OCI Object Storage   | PASS   |
| Fuzzy Search   | Search for 'NYIT' with typo 'NYuT'       | PASS   |
| Messaging      | Send and receive real-time pet inquiries | PASS   |

3. GEOSPATIAL VALIDATION
Special attention was given to the PostGIS spatial logic. Tests were performed 
by manually updating user coordinates in the database to verify that the 
'Nearby Pets' feed correctly filtered out records beyond the specified 
distance threshold.

4. ENVIRONMENT STATUS
- Backend Stability: Verified on local Uvicorn server and Oracle Cloud.
- Frontend Stability: Verified on Android Emulator (API 36) and physical 
  iOS hardware.

**PAWNDER | TECH STACK & SYSTEM REQUIREMENTS**

1. CORE TECH STACK
- Frontend Framework: Flutter (Dart)
- Backend Framework: FastAPI (Python 3.10+)
- Primary Database: PostgreSQL 14+
- Database Extensions: PostGIS (Spatial), pg_trgm (Search), uuid-ossp (IDs)
- Infrastructure: Oracle Cloud Infrastructure (OCI) Object Storage
- ORM: SQLAlchemy (Synchronous/Asynchronous support)

2. SOFTWARE REQUIREMENTS
To build or run this project locally, the following software must be installed:

- Java Development Kit (JDK): Version 17
- Python: Version 3.10 or higher
- Flutter SDK: Stable channel
- Android SDK: Platform API 36
- PostgreSQL: Version 14 or higher (with PostGIS bundle)

3. HARDWARE & PLATFORM SUPPORT
- Android: Compatible with devices running Android 5.0 (API 21) or higher. 
  The project is configured to compile against API 36.
- iOS: Compatible with iOS 12.0 or higher (requires macOS and Xcode).
- Development Machine: Minimum 8GB RAM (16GB recommended for running 
  Android emulators and the backend server at the same time).

4. THIRD-PARTY PACKAGES & APIS
- OCI Python SDK: Handles authenticated requests to Oracle Cloud for 
  media storage and database backups.
- Geocoding/Maps: Utilizes PostGIS for native spatial calculations and 
  distance filtering between users and pets.
- CORS Middleware: Configured in the FastAPI core to allow local development 
  across specific origin patterns.

**PAWNDER | CONTRIBUTORS & ROLES**

- Justin Bruinsma: Group Leader & Lead Backend Developer
  
Responsible for overall project management, system architecture, database 
  design, and OCI setup, integration, and maintenance.

- Mohamed Loum: Supporting Backend Developer
  
Provided support for backend development and helped with OCI setup and integration.

- Matthew Campoverde: Frontend Development Lead
  
Focused on the UI/UX design and development of core application features 
  within the Flutter framework.

- Devin He: Supporting Frontend Developer 

Contributed to the implementation of mobile UI components and client-side 
  logic.

- Sia Brewton: Supporting Backend Developer
  
Helped with the development of API endpoints and backend business logic.

- Roux Grinion: Supporting Frontend Developer

Collaborated on the development and styling of frontend modules and user interfaces.
