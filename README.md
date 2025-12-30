# Moderne Migration Practice Environment

This workspace provides a practice environment for migrating a legacy e-commerce system composed of multiple independent Maven projects to modern Java and Spring Boot.  The components for this practice environment are housed in separate repositories in GitHub, just like they would in a normal distributed organization.

This here provides a centralized set of guides along with the `repos.csv` file used to clone all of these applications and work with them using the Moderne CLI. 

## Environment overview

### Services

| Service | Spring Boot Version | Port | Description |
| :--- | :--- | :--- | :--- |
| **`product-service`** | 2.3.12.RELEASE | 8080 | Manages the product catalog. Exposes REST endpoints. |
| **`customer-service`** | 2.4.13 | 8081 | Manages customer profiles. Exposes REST endpoints. |
| **`order-service`** | 2.5.15 | 8082 | Handles order placement. Orchestrates calls to Product and Customer services and publishes events. |
| **`inventory-service`** | 2.2.13.RELEASE | 8083 | Tracks stock levels. Listens to `OrderCreatedEvent` to deduct inventory. |
| **`notification-service`** | 2.6.15 | 8084 | Sends notifications (email/SMS). Listens to `OrderCreatedEvent`. |
| **`kyc-service`** | 2.4.13 | 8085 | Performs background checks (Mocked: Always Allow). |
| **`risk-score-service`** | 2.3.12.RELEASE | 8086 | Calculates risk score using Drools rules. |
| **`fraud-detection-service`** | 2.5.15 | 8087 | Orchestrates fraud checks by calling KYC and Risk services. |

### Shared Libraries

-   **`ecom-common`**: Contains shared DTOs (e.g., `OrderCreatedEvent`, `ApiResponse`), utilities, and exceptions.
-   **`ecom-security`**: Provides standardized Spring Security configuration and JWT utilities.
-   **`ecom-rest-client`**: Provides a standarded Feign client for making HTTP requests to other services.

### Legacy Dependencies

-   **QueryDSL 3.2.3**: Used for persistence layer type-safe queries in all services. Configured with `apt-maven-plugin`.

### System Architecture

The system follows a microservices architecture with both synchronous (REST) and asynchronous (RabbitMQ) communication.

```mermaid
graph TD
    subgraph "Shared Libraries"
        Common[ecom-common]
        Security[ecom-security]
    end

    subgraph "Core Services"
        Product["product-service<br/>(Boot 2.3)"]
        Customer["customer-service<br/>(Boot 2.4)"]
        Order["order-service<br/>(Boot 2.5)"]
    end

    subgraph "Support Services"
        Inventory["inventory-service<br/>(Boot 2.2)"]
        Notify["notification-service<br/>(Boot 2.6)"]
    end

    subgraph "Fraud Detection"
        Fraud["fraud-detection-service<br/>(Boot 2.5)"]
        KYC["kyc-service<br/>(Boot 2.4)"]
        Risk["risk-score-service<br/>(Boot 2.3)"]
    end

    subgraph "Infrastructure"
        RabbitMQ((RabbitMQ))
        H2[(H2 Database)]
    end

    %% Dependencies
    Product --> Common
    Product --> Security
    Customer --> Common
    Customer --> Security
    Order --> Common
    Order --> Security
    Inventory --> Common
    Inventory --> Security
    Notify --> Common
    Notify --> Security
    Fraud --> Common
    Fraud --> Security
    KYC --> Common
    KYC --> Security
    Risk --> Common
    Risk --> Security

    %% Communication
    Order -- "REST (Feign)" --> Product
    Order -- "REST (Feign)" --> Customer
    Order -- "REST (Feign)" --> Fraud
    Fraud -- "REST (Feign)" --> KYC
    Fraud -- "REST (Feign)" --> Risk
    Order -- "Publishes Event" --> RabbitMQ
    RabbitMQ -- "Consumes Event" --> Inventory
    RabbitMQ -- "Consumes Event" --> Notify

    %% Database
    Product --> H2
    Customer --> H2
    Order --> H2
    Inventory --> H2
```

### Information Flow: Order Creation

When a user places an order, the `order-service` orchestrates the process.

```mermaid
sequenceDiagram
    participant User
    participant Order as Order Service
    participant Fraud as Fraud Service
    participant KYC as KYC Service
    participant Risk as Risk Service
    participant Product as Product Service
    participant Customer as Customer Service
    participant DB as Order DB
    participant RMQ as RabbitMQ
    participant Inventory as Inventory Service
    participant Notify as Notification Service

    User->>Order: POST /api/orders
    activate Order
    
    Note over Order: Validate Request

    Order->>Fraud: POST /api/fraud/check
    activate Fraud
    Fraud->>KYC: POST /api/kyc/check
    activate KYC
    KYC-->>Fraud: ALLOW
    deactivate KYC
    Fraud->>Risk: POST /api/risk/assess
    activate Risk
    Risk-->>Fraud: HIGH/MEDIUM/LOW
    deactivate Risk
    Fraud-->>Order: ALLOWED/BLOCKED
    deactivate Fraud

    alt Fraud Check Failed
        Order-->>User: 400 Bad Request (Blocked)
    else Fraud Check Passed
        Order->>Product: GET /api/products/{id}
        activate Product
        Product-->>Order: Product Details (Price, Name)
        deactivate Product

        Order->>Customer: GET /api/customers/{id}
        activate Customer
        Customer-->>Order: Customer Details
        deactivate Customer

        Order->>DB: Save Order
        activate DB
        DB-->>Order: Order Saved
        deactivate DB

        Order->>RMQ: Publish OrderCreatedEvent
        activate RMQ
        RMQ-->>Order: Ack
        deactivate RMQ

        Order-->>User: 200 OK (OrderDto)
    end
    deactivate Order

    par Async Processing
        RMQ->>Inventory: Deliver OrderCreatedEvent
        activate Inventory
        Inventory->>Inventory: Deduct Stock
        deactivate Inventory
    and
        RMQ->>Notify: Deliver OrderCreatedEvent
        activate Notify
        Notify->>Notify: Send Email
        deactivate Notify
    end
```

## Setting up the initial state

1. Clone the repositories to an empty directory (we'll refer to this as your workspace from now on):
    ```bash
    mod git sync csv . <moderne-migration-practice-repo>/repos.csv --with-sources
    ```
2. All projects should build out of the box using their predefined older dependencies. In your workspace, you can build all of the projects:
    ```bash
    mod exec . -- mvn clean package
    ```
3. You'll need to have lossless semantic trees (LSTs) built for all of the repositories in order to run recipes:
    ```bash
    mod build .
    ```
4. You can run all of the services locally using Docker with the included docker-compose.yml in this directory:
    ```bash
    WORKSPACE="<PATH TO WORKSPACE>" docker-compose up --build
    ```
    This will start all services along with third-party dependencies such as RabbitMQ, Keycloak, and Jaeger. The services will be available at their respective ports (e.g., `product-service` at 8080, `order-service` at 8082).

## Testing the system

There are Postman collections provided for running some common workflows in the system in the `api-tests` directory.  These can be used to generate some traffic on the services so that you can see them traced using the Jaeger UI at [http://localhost:16686](http://localhost:16686).