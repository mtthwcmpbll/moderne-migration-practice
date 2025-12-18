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

## Starting a migration

1. Run a spring boot migration recipe to see if it works out of the box: `mod run . --recipe io.moderne.java.spring.boot4.UpgradeSpringBoot_4_0`
1. Apply the suggested changes to all projects: `mod git apply . --last-recipe-run `
1. Check to see if projects compile after the recipe: `mod exec . -- mvn clean package`
1. Rebuild the LSTs so they reflect the new changes and the mod CLI will detect the new Java versions: `mod build .`
We can see that only a couple of our projects - some but not all of our shared libraries - successfully build now.

1. Next, we can try to do our migration in layers to get some iterative value and see where things break down:
    1. Upgrade build tools:
        - `mod run . --recipe org.openrewrite.maven.UpdateMavenWrapper -P "wrapperVersion=3.3.4" -P "wrapperDistribution=script" -P "distributionVersion=3.9.11" -P "addIfMissing=true"`
        - Note that this doesn't seem to work correctly at the moment, only upgrading some repositories but not others.
    1. Upgrade test framework:
        - We know JUnit 6 requires a minimum of Java 17, so we can do JUnit 5 first so that we have a smaller changeset when we upgrade Java.
        - `mod run . --recipe org.openrewrite.java.testing.junit5.JUnit5BestPractices`
        - `mod git apply . --last-recipe-run`
        - If we try to build everything now, we see this is broken in some projects because of `@RunWith(SpringJUnit4ClassRunner.class)`.  This tells us we probably should upgrade Spring _before_ upgrading JUnit.
    1. Spring Boot 2.7 has better support for modern Java versions including Java 17, so let's upgrade that first.
        - `mod run . --recipe org.openrewrite.java.spring.boot2.UpgradeSpringBoot_2_7`
        - `mod git apply . --last-recipe-run`
        - If we build now, we see that some projects fail to build because of a removed spring-cloud-starter-zipkin dependency.  We can replace this dependency with it's new version.
    1. Replace the spring-cloud-starter-zipkin dependency with it's new version spring-cloud-sleuth-zipkin:
        - `mod run . --recipe org.openrewrite.maven.ChangeDependencyGroupIdAndArtifactId -P "oldGroupId=org.springframework.cloud" -P "oldArtifactId=spring-cloud-starter-zipkin" -P "newGroupId=org.springframework.cloud" -P "newArtifactId=spring-cloud-sleuth-zipkin"`
        - `mod git apply . --last-recipe-run`
        - Test the build and this should still be building successfully.  3 projects should have updated as a result of this recipe.
    1. Go back and run the Spring Boot 2.7 upgrade again.  Apply and build it.  This should build now, and you've officially upgraded Spring Boot to 2.7.
    1. Next up, let's return to our JUnit upgrade.  Rerun and retest.  This should now pass because the upgrade to Spring Boot 2.7 removed the unneeded `@RunWith` annotation.  Now we've upgraded JUnit to 5.
    1. Although future migration recipes may fix the javax-to-jakarta migration, we can do this as another layer here:
        - `mod run . --recipe org.openrewrite.java.migrate.jakarta.JakartaEE11`
        - `mod git apply . --last-recipe-run`
        - test build
    1. To go to Spring Boot 3.x onward or JUnit 6, we'll need to upgrade Java to 17 or higher.  Let's tackle that upgrade next, so that we're isolating those specific changes.
        - `mod run . --recipe org.openrewrite.java.migrate.UpgradeToJava17`
        - `mod git apply . --last-recipe-run`
        - This should build successfully - we're up to a new version of Java!
    1. Let's also run Maven Best Practices to make sure that we're not going to get surprised by any well-known issues like code building for a different version of Java than we expect:
        - `mod run . --recipe org.openrewrite.maven.BestPractices`
        - `mod git apply . --last-recipe-run`
    
    
1. Let's run some migration planning recipes to see what we can learn:
    ```bash
    # DevCenterStarter
    mod run . --recipe io.moderne.devcenter.DevCenterStarter
    mod devcenter . --last-recipe-run

    # PlanJavaMigration
    mod run . --recipe org.openrewrite.java.migrate.search.PlanJavaMigration
    mod study . --last-recipe-run --data-table JavaVersionMigrationPlan
    ```

    PlanJavaMigration gives us current Java version and if its a Gradle or Maven project.  I'm not sure there's a lot of actionable info here that should change out mind about approach, just situational awareness.

    Let's see if we can find which Spring Boot versions we're using:
    ```bash
    mod run . --recipe org.openrewrite.java.dependencies.DependencyInsight -P "groupIdPattern=org.springframework.boot" -P "artifactIdPattern=spring-boot" -P "scope=runtime"
    ```
1. TODO: Find shared libraries or other kinds of dependencies across repositories
1. TODO: Find projects that are limited in the Java version they can use'





mod run . --recipe org.openrewrite.maven.UpdateMavenWrapper -P "distributionVersion=3.9.11" -P "addIfMissing=true" -P "wrapperDistribution=script"