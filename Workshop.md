# Moderne Migration Practice Environment

## Setup

> Note:  We'll use a couple of conventions in this document to refer to some common directories.  `$WORKSHOP` will refer to the root of this repository.  `$WORKSPACE` will refer to the directory you're cloning repos into and running `mod` commands against.  If you want to make this simpler and run commands compied directly from this workshop guide, you can use `export WORKSPACE=~/workspaces/migration_workshop` and `export WORKSHOP=~/projects/moderne-migration-practice` in your shell session.  Replace the values of these variables with their real locations on your hard drive.

Let's start by using the Moderne CLI to clone all of our example repositories into an empty directory:

```bash
# Navigate to your empty workspace (make sure you've set $WORKSPACE in your shell previously, or just replace it with the actual place you want to go)
cd $WORKSPACE

# Clone all of our example repositories into the workspace with their source code so that we can apply suggested changes from recipes
mod git sync $WORKSHOP/repos.csv --with-sources

# Build an LST for each project
mod build $WORKSPACE
```

This last command will take a few minutes to run as it compiles the projects and builds the Lossless Semantic Trees (LSTs) for each project.

For a deterministic workshop, clear your installed recipes (if you have already installed some) and install the following recipe artifacts:

```bash
mod config recipes delete

mod config recipes jar install io.moderne.recipe:rewrite-ai:0.1.0 io.moderne.recipe:rewrite-angular:0.1.2 io.moderne.recipe:rewrite-cryptography:0.11.4 io.moderne.recipe:rewrite-devcenter:1.13.1 io.moderne.recipe:rewrite-elastic:0.4.3 io.moderne.recipe:rewrite-hibernate:0.15.2 io.moderne.recipe:rewrite-jasperreports:0.2.1 io.moderne.recipe:rewrite-kafka:0.4.3 io.moderne.recipe:rewrite-program-analysis:0.8.0 io.moderne.recipe:rewrite-react:0.1.2 io.moderne.recipe:rewrite-spring:0.19.0 io.moderne.recipe:rewrite-vulncheck:0.5.0 org.openrewrite:rewrite-cobol:2.13.0 org.openrewrite:rewrite-core:8.69.0 org.openrewrite:rewrite-csharp:0.27.27 org.openrewrite:rewrite-gradle:8.69.0 org.openrewrite:rewrite-groovy:8.69.0 org.openrewrite:rewrite-hcl:8.69.0 org.openrewrite:rewrite-java:8.69.0 org.openrewrite:rewrite-javascript:8.69.0 org.openrewrite:rewrite-json:8.69.0 org.openrewrite:rewrite-kotlin:8.69.0 org.openrewrite:rewrite-maven:8.69.0 org.openrewrite:rewrite-polyglot:2.9.1 org.openrewrite:rewrite-properties:8.69.0 org.openrewrite:rewrite-protobuf:8.69.0 org.openrewrite:rewrite-python:1.44.3 org.openrewrite:rewrite-templating:1.38.3 org.openrewrite:rewrite-toml:8.69.0 org.openrewrite:rewrite-xml:8.69.0 org.openrewrite:rewrite-yaml:8.69.0 org.openrewrite.meta:rewrite-analysis:2.31.0 org.openrewrite.recipe:rewrite-ai-search:0.32.3 org.openrewrite.recipe:rewrite-all:1.23.3 org.openrewrite.recipe:rewrite-android:0.15.2 org.openrewrite.recipe:rewrite-apache:2.20.3 org.openrewrite.recipe:rewrite-azul:0.8.3 org.openrewrite.recipe:rewrite-circleci:3.9.3 org.openrewrite.recipe:rewrite-codemods:0.23.1 org.openrewrite.recipe:rewrite-codemods-ng:0.16.1 org.openrewrite.recipe:rewrite-compiled-analysis:0.11.2 org.openrewrite.recipe:rewrite-comprehension:0.10.2 org.openrewrite.recipe:rewrite-concourse:3.9.3 org.openrewrite.recipe:rewrite-cucumber-jvm:2.11.3 org.openrewrite.recipe:rewrite-docker:2.14.3 org.openrewrite.recipe:rewrite-dotnet:0.14.3 org.openrewrite.recipe:rewrite-dropwizard:0.8.3 org.openrewrite.recipe:rewrite-feature-flags:1.17.0 org.openrewrite.recipe:rewrite-github-actions:3.16.1 org.openrewrite.recipe:rewrite-gitlab:0.17.3 org.openrewrite.recipe:rewrite-hibernate:2.16.2 org.openrewrite.recipe:rewrite-jackson:1.13.0 org.openrewrite.recipe:rewrite-java-dependencies:1.48.0 org.openrewrite.recipe:rewrite-java-security:3.24.0 org.openrewrite.recipe:rewrite-jenkins:0.33.2 org.openrewrite.recipe:rewrite-joda:0.5.1 org.openrewrite.recipe:rewrite-kubernetes:3.14.1 org.openrewrite.recipe:rewrite-liberty:1.23.3 org.openrewrite.recipe:rewrite-logging-frameworks:3.20.0 org.openrewrite.recipe:rewrite-micrometer:0.28.0 org.openrewrite.recipe:rewrite-micronaut:2.30.3 org.openrewrite.recipe:rewrite-migrate-java:3.24.0 org.openrewrite.recipe:rewrite-netty:0.6.3 org.openrewrite.recipe:rewrite-nodejs:0.36.0 org.openrewrite.recipe:rewrite-okhttp:0.21.0 org.openrewrite.recipe:rewrite-openapi:0.27.3 org.openrewrite.recipe:rewrite-quarkus:2.28.3 org.openrewrite.recipe:rewrite-reactive-streams:0.18.3 org.openrewrite.recipe:rewrite-rewrite:0.17.0 org.openrewrite.recipe:rewrite-spring:6.21.0 org.openrewrite.recipe:rewrite-spring-to-quarkus:0.4.1 org.openrewrite.recipe:rewrite-sql:2.8.3 org.openrewrite.recipe:rewrite-static-analysis:2.24.0 org.openrewrite.recipe:rewrite-struts:0.23.3 org.openrewrite.recipe:rewrite-terraform:3.11.3 org.openrewrite.recipe:rewrite-testing-frameworks:3.24.0 org.openrewrite.recipe:rewrite-third-party:0.32.1 
```

This `repos.csv` lists all of our example repositories, and you can view the final workspace structure to see that you have a directory for the GitHub org (or user) with the repositories inside:

```bash
tree -d . -L 3
```

## Step 0: Run the full migration

First up, you can always start by running the full migration recipe that we ultimately want to finish with.  This often gives us some information on some of the obvious pitfalls that we might run into, including incompatible libraries or additional customizations that we need to make to the recipe. Go ahead and run the upgrade Spring Boot 4.0 recipe now:

```bash
# Run the recipe
mod run $WORKSPACE --recipe io.moderne.java.spring.boot4.UpgradeSpringBoot_4_0

# Apply the suggested changes to all projects
mod git apply . --last-recipe-run
```

This repository includes some helper scripts to run commands like testing, releasing, and doing common git actions across your repositories.  You can run `mvn clean install` on all projects with the `build.sh` script:

```bash
$WORKSHOP/build.sh
```

> Note: To ensure reproducible builds, projects refer to each other with specific release versions - not SNAPSHOTs or other dynamic references. This simulates an environment in a large organization where each of these repositories is owned by different teams and released independently.  This probably isn't the case for _every_ repository in your portfolio - there's likely collections of related repositories that are all built and released together as a constellation of services.  In our workshop, we'll simplify this to "every repository is independent from the others" to make sure we practice this particular speed bump.

Take a second to look at the output for the failed Maven builds. Why doesn't this work?

While every repository presents its own unique challenges, there are common speed bumps along the way that we can look for in any set of depositors. These include:

- Inconsistent or brittle build tool configuration
- Incompatible build tool versions (both the tools themselves and their plugins)
- Third-party dependencies that are incompatible with new versions of Java or upgraded frameworks
- Dependencies between repositories in the whole set that need to be built in order

In the example applications, we can see that there's actually a number of issues:

- We're failing to build some classes like `QOrder` and `QInventory`. These "Q" classes are coming from a code generator called QueryDSL, and code generators are a class of tools that are generally problematic during migrations.  They often generate code that's specifically tuned for a particular version of Java or frameworks like Spring.  Upgrading those runtimes often require an update to the code generator.
- We're seeing failures compiling test classes with errors like `package org.springframework.boot.test.autoconfigure.web.servlet does not exist`. Upgrading Spring also includes upgrading to a newer version of JUnit, so this might require us to update our tests, or we might be pulling in outdated testing libraries as dependencies.
- Errors like `'dependencies.dependency.version' for org.springframework.cloud:spring-cloud-starter-zipkin:jar is missing.` sounds like these used to be managed dependencies in our older Spring Boot versions but now there is no managed version specified in Spring Boot 4.0.  This can happen when the dependency has move or been replaced by a different Spring Boot starter, or if the particular functionality was deprecated and removed.

### What makes a third-party library incompatible with newer versions of Java?

While you can run libraries compiled with an older version of Java in newer versions of JVM, the Java runtime has deprecated specific APIs and ultimately removed or refactored those as it has evolved.  The major change that many people run into includes many `javax.*` internal APIs, including the Java EE APIs that were ultimately moved out of the JVM entirely and into the Jakarta namespace.

### Why do we care about dependencies between repositories as we're going through a migration?

Large organizations often have repositories that depend on each other, using internal shared libraries to share code and standardize specific functionality.  These shared libraries can be owned, built, released, and versioned independently from the repositories that use them, so we need to upgrade these projects _and_ run them through their whole software developer lifecycle to release a new updated version that downstream consumers can move to.  This can sometimes be as simple as upgrading a version number in a build manifest, or it can include complex code changes for those consumers to upgrade their code depending on how the libraries are built.  Regardless, in order to upgrade all of our repositories, we often need to find the sets of repositories that are depended on and upgrade them in the first waves of our migration.

Go ahead and reset our repositories to a clean state now that we've learned from this experiment:

```bash
$WORKSHOP/git.sh restore .
```

## Step 1: Code Insight

We can learn a lot about out project by running recipes designed to analyze our codebase and extract information about these common speed bumps.  

### PlanJavaMigration

Let's find out if we're using Maven or Gradle in our projects, and which versions of Java we're currently using:

```bash
# Run the recipe
mod run $WORKSPACE --recipe org.openrewrite.java.migrate.search.PlanJavaMigration

# Extract a CSV data table containing our information
mod study $WORKSPACE --last-recipe-run --data-table JavaVersionMigrationPlan
```

Take a look at the CSV file reported in by that last command to see that we're using Java 8 and Maven across the board.  In larger portfolios this can be helpful to locate groups of repositories that will take extra work to bring up to date, and can be an early warning signal pointed toward speed bumps your likely to encounter.

### DependencyInsight

Next up, let's check and see which versions of Spring Boot we're on:

```bash
mod run $WORKSPACE --recipe org.openrewrite.java.dependencies.DependencyInsight -P "groupIdPattern=org.springframework.boot" -P "artifactIdPattern=spring-boot" -P "scope=runtime"

# Extract a CSV data table containing our information
mod study $WORKSPACE --last-recipe-run --data-table DependenciesInUse
```

Looking at that data table should show that we're using a spread of Spring Boot 2.x versions.

### Find Types to Find common `javax.*` APIs

We know that many common `javax.*` APIs like JPA, validation, and servlet APIs moved to the Jarkarta namespace.  Libraries and frameworks using the old packages can make it hard to upgrade to newer versions of Java.  Let's find out if we're using any of those APIs:

```bash
# Run the recipe
mod run $WORKSPACE --recipe org.openrewrite.java.search.FindTypes -P "fullyQualifiedTypeName=javax..*"

# Extract a CSV data table containing our information
mod study $WORKSPACE --last-recipe-run --data-table TypeUses
```

This recipe shows that we're using the validation and persistence APIs, so we'll need to keep an eye on these and make sure that migration recipes upgrade to the new packages.

### Search for code generators with Find Plugins

We know that code generators can be a challenge when upgrading our repositories, and we know that we're using QueryDSL in some or all of these repositories.  This tool uses a Maven plugin to generate its code, so we can find which projects are likely to need some extra effort upgrading this tool with the following:

```bash
# Run the recipe
mod run $WORKSPACE --recipe org.openrewrite.maven.search.FindPlugin -P "groupId=com.mysema.maven" -P "artifactId=apt-maven-plugin"

# Extract a CSV data table containing our information
mod study $WORKSPACE --last-recipe-run --data-table SourcesFileResults
```

This shows that four of our services are using QueryDSL as part of their persistence layer.

### DevCenter

Another great tool that can help us answer some of these questions and monitor our migration progress over time is the DevCenter.  This is a special recipe that the Moderne CLI can use to build an HTML dashboard tracking our various migration goals.  Let's build a devcenter for our repositories now:

```bash
# Run the recipe
mod run $WORKSPACE --recipe io.moderne.devcenter.DevCenterStarter

# Use the devcenter command to generate our dashboard
mod devcenter . --last-recipe-run
```

Open up the HTML file provided in the output for that last command in a browser and you'll see visualizations for our 11 repositories showing which ones have been ugpraded to Java 25 and Spring Boot 4.0 (spoiler alert: none of them have been upgraded yet). We'll periodically rerun DevCenter as we go through this migration to see how this changes over time.

### Other usefule code insight recipes for migration planning

- FindInternalJavaxApis filtering for our own base package `com.example.ecom.*` names will help find repositories that are using problematic Java APIs.
- FindDeprecatedUses will show if we're using any deprecated APIs or classes.  If these are already deprecated in our current configuration, they may end up being removed in the version we're upgrade to.
- RelocatedDependencyCheck will help you find common dependencies that have been relocated to new groupId/artifactId coordinates in your dependency manager.  It can also help change to the new coordinates, but it's a useful tool just to highlight libraries that have gone through changes between your current state and your target state.

## Step 2: Wave Planning

This is a special case of code insight - let's use the rich data we have in our LSTs about repository dependencies (direct _and_ transitive) to help us map our which of our repositories depend on each other.  This should give us a list of repositories that don't depend on any others - this is our first wave that's save to upgrade now.  Once we've upgraded this first wave, we'll need to release it and have our next wave (those repositories that depend on projects in the first wave) upgrade their dependencies to these new versions.

First things first, let's check out Merlin's metro mapping project to help us do the wave planning.  Navigate to somewhere outside of your `$WORKSPACE`, clone the GitHub repository, and build and install the recipe artifact locally:

```bash
# Clone the repository - switch to HTTPS if you that's your preference here
git clone git@github.com:MBoegers/Release-Train-Metro-Plan.git

cd Release-Train-Metro-Plan

# Build the recipe artifact and install it into your local maven cache
./gradlew clean publishToMavenLocal

# Install the recipe artifact into your Moderne CLI from your maven cache
mod config recipes jar install dev.mboegie.rewrite:release-train-metro-plan:0.1.0-SNAPSHOT
```

You now have some new recipes available to your Moderne CLI.  Let's use one of them to help us plan our upgrade waves:

```bash
mod run $WORKSPACE --recipe dev.mboegie.rewrite.releasemetro.ReleaseMetroPlan --parallel
```

This recipe will generate a bunch of CSV data tables and will output the list of them in the next steps section.  Let's generate the handful we need:

```bash
mod study $WORKSPACE --last-recipe-run --data-table ParentRelationships
mod study $WORKSPACE --last-recipe-run --data-table ProjectCoordinates
mod study $WORKSPACE --last-recipe-run --data-table UnusedDependencies
mod study $WORKSPACE --last-recipe-run --data-table DependenciesInUse
```

Each of these will output a path to a new CSV data table.  You can use the Kotlin Jupyter notebook provided in the Release-Train-Metro-Plan repository to help you analyze the data in these tables and plan your upgrade waves.  Set the values for the various `val`s to the paths of the CSV data tables you just generated and run the notebook.  Open the HTML file in that repo under `src/main/static/metro-plan.html` and you should see an interactive visualization based on the repository dependencies and, crucially, an ordered collection of waves:

**Wave 0:**
- example-ecom-common

**Wave 1:**
- example-ecom-security
- example-ecom-inventory-service
- example-ecom-kyc-service
- example-ecom-notification-service
- example-ecom-risk-score-service

**Wave 2:**
- example-ecom-rest-client
- example-ecom-customer-service
- example ecom-product-service

**Wave 3:**
- example-ecom-order-service
- example-ecom-fraud-detection-service

With these waves identified, we need to do a little reorganization so that we can run recipes against the subset of repositories in a particular wave and then cut a new versioned release for downstream consumers to upgrade to.  We can do this in a couple of ways:

1. You can create multiple `repos.csv` files, one for each wave.  You can then `mod git sync csv` each wave into their own workspace to work on them in isolation.
2. You can manually navigate into each repository in a wave and run `mod` commands on just that one repository.  This is manually intensive even at 11 repositories, and is untenable at scale.  If you only have a few repositories, it can get the job done though.
3. You can use the organization structure feature of the `repos.csv` file to group repositories into waves. When you run `mod git sync csv` on a `repos.csv` with organization columns, it will automatically put those repositories into separate directories in your workspace.  This allows you to dive into a specific wave's directory to run recipes against just those repositories, but lets you continue to run code insight and DevCenter recipes at the root of your workspace for a big picture view.

We'll use option 3 during this workshop.  This repository provides a second file called `repos-waves.csv` and you can rerun the following in your workspace to reorganize it to include waves in the directory structure:

```bash
mod git sync csv . $WORKSHOP/repos-waves.csv --with-sources
mod build $WORKSPACE
```

> Note: You may get a message stating `The directory currently represents the organization ε. Do you want to replace it [Yn]?`. This is just saying that your workspace already has an unnamed root organization checked out, and you'll be replacing it with the new organization structure.  You can safely hit `Y` to process and it will delete the existing repositories in your workspace and reclone them into the new heirarchy.

Check out your new structure:

```bash
tree -d . -L 3
```

Alright, we're ready to start making actual changes to our repositories!

## Step 3: Level-Set Your Baseline

> Optional step:  You can use the included `git.sh` to switch over to a new branch in all of the repositories if you want to commit changes step by step: `$WORKSHOP/git.sh checkout -b migration-workshop`

When we're doing some upgrades, it's often helpful to run the upgrade recipes for the language and frameworks we _think_ we're already running.  This gives us a common baseline to start building on top of, instead of having many different flavors of "Spring 2.x" or "Maven projects".

```bash
# Run the recipe
mod run $WORKSPACE --recipe org.openrewrite.maven.BestPractices

mod git apply . --last-recipe-run

# Test that everything still builds correctly after our changes
$WORKSHOP/build.sh

# Rebuild the LSTs to match the new state of the codebase
mod build $WORKSPACE
```

> Note: From here on out, I'll exclude the `build.sh` step that runs `mvn clean install` to verify things compile and the `mod build` step that rebuilds the LSTs.  You'll need to run these after each recipe.

This should build successfully.  Since we're on a variety of Spring Boot 2.x versions, let's also run the recipe to upgrade to Spring Boot 2.7 since that includes better support for Java 17+, newer testing frameworks, etc.  But first, we know from our earlier code insight that we're using a dependency `spring-cloud-starter-zipkin` which is no longer supported, so let's run a recipe to change it to the new correct dependency to avoid Spring Boot 2.7 complaining at us:

```bash
# Run the recipe to change a dependency's artifactId
mod run . --recipe org.openrewrite.maven.ChangeDependencyGroupIdAndArtifactId -P "oldGroupId=org.springframework.cloud" -P "oldArtifactId=spring-cloud-starter-zipkin" -P "newGroupId=org.springframework.cloud" -P "newArtifactId=spring-cloud-sleuth-zipkin"

# Apply the changes suggested by the recipe
mod git apply . --last-recipe-run
```

Now let's upgrade our baseline to Spring Boot 2.7:

```bash
# Run the recipe
mod run $WORKSPACE --recipe org.openrewrite.java.spring.boot2.UpgradeSpringBoot_2_7

# Apply the suggested changes
mod git apply $WORKSPACE --last-recipe-run
```

Let's do the same thing for our Java version - we're on Java 8, so let's make sure we're following the best practices for this version of Java as a starting point:

```bash
# Run the recipe
mod run $WORKSPACE --recipe org.openrewrite.java.migrate.UpgradeToJava8

# Apply the suggested changes
mod git apply $WORKSPACE --last-recipe-run
```

Everything up until this point should be build successfully so far, and we're now at a common baseline across the repositories.

## Step 4: Our first major upgrade

We could try upgrading Spring Boot to 4.0 now, but that might still be a larger changeset with many speed bumps between us and a successful release of some new value.  Let's start with a much smaller change and upgrade our Java to 17, since we know that's a prerequisite for JUnit 6 and Spring Boot 3.x.

> We can't upgrade to Java 25 yet because it wasn't released when Spring Boot 2.7 was most recently released, so those dependencies are incompatible with Java 25's class file format.  Give it a try and see what happens with `mod run . --recipe org.openrewrite.java.migrate.UpgradeToJava25`

Run the upgrade to Java 17:

```bash
mod run $WORKSPACE --recipe org.openrewrite.java.migrate.UpgradeToJava17

mod git apply $WORKSPACE --last-recipe-run
```

The Spring Boot 4.0 upgrade recipe will upgrade to newer versions of JUnit too, but changing your test framework and changing your Spring application logic can be very different kinds of updates.  Every iteration of our migration that we can build and push raises the water line for all of our repositories and makes future migration changesets easier to review and promote to production releases because they're smaller and more focused.  Let's upgrade to JUnit 6 next so that we case focus on test dependencies and libraries separately from our application code:

```bash
mod run $WORKSPACE --recipe org.openrewrite.java.testing.junit.JUnit6BestPractices 

mod git apply $WORKSPACE --last-recipe-run
```

Finally, let's upgrade to Spring Boot 4.0:

```bash
mod run $WORKSPACE --recipe org.openrewrite.java.spring.boot4.UpgradeSpringBoot_4_0

mod git apply $WORKSPACE --last-recipe-run
```

Up until this point, we've been running recipes against the entire workspace.  Applying the changes to any given repository hasn't been _incompatible_ with the old released versions of the internal shared libraries still being used across the codebase.  The Spring Boot 4.0 upgrade is different though, and you should be seeing build failures in some projects.  The `build.sh` script takes a parameter specifying the wave to build so that you can build specific waves and narrow in on problems:

```bash
$WORKSHOP/build.sh 0
```

Wave one builds fine (it's only one project with no internal dependencies after all!).

```bash
$WORKSHOP/build.sh 1
```

Some projects in this wave fail due to the incompatible QueryDSL code generator library.  Let's deal with that next.

## Step 5: Upgrading QueryDSL

You'll often run into third-party libraries that you're using that need some code changes to upgrade above and beyond just bumping a dependency version to a newer release.  QueryDSL 3.x generates classes using the outdated `javax.*` namespaces, but it's also gone through some restructuring in newer releases that have changed package names and APIs.  This is a good example of running into a speed bump that will require you to write a custom recipe to get past.  In this case, custom recipe authorship is outside the scope of this workshop so [we've written one for you](https://github.com/mtthwcmpbll/rewrite-querydsl).  Similar to the Release-Train-Metro-Plan earlier, you'll need to clone this repository and build and install it locall to use it in the Moderne CLI:

```bash
git clone git@github.com:mtthwcmpbll/rewrite-querydsl.git

cd rewrite-querydsl

mvn clean install

mod config recipes jar install org.openrewrite.recipe:rewrite-querydsl:0.1.0-SNAPSHOT
```

This new project introduces a custom recipe `org.openrewrite.recipe.querydsl.UpgradeToQueryDsl5` that renames packages, changes dependencies, and updated APIs to move from QueryDSL 3.x to QueryDSL 5.x as it's used in these examples.

There's a chicken-and-egg problem here though - newer versions of QueryDSL require Spring Boot 3+ that has moved to the new `jakarta.*` namespace, but we can't run the Spring Boot upgrade because it will fail to compile the older QueryDSL generated code.  We need to do both of these at the same time.

This is an example of a migration recipe _freight train_ - you'll often build a custom recipe that runs the out-of-the-box recipes and then applies some additional ones that are needed in your particular environment.  As you try migrating new repositories you'll find additional speed bumps that will drive you to enhance your custom recipes to move forward for more and more teams.  You build momentum while you're running migrations and enhancing your custom recipes to make it turn-key for more and more repositories.  In this case, the custom recipe repository also contains a recipe named `org.openrewrite.recipe.querydsl.CustomUpgradeSpringBoot_4_0` that combines the Spring Boot 4.0 upgrade and our QueryDSL upgrade into a single recipe.  Let's run that now for the first wave:

```bash
cd $WORKSPACE/Wave1

mod run $WORKSPACE --recipe org.openrewrite.recipe.querydsl.CustomUpgradeSpringBoot_4_0

mod git apply $WORKSPACE --last-recipe-run
```

Test that this builds successfully:

```bash
$WORKSHOP/build.sh 0
```

If this build successfully, release this wave of projects by building a release artifact and incrementing to the next SNAPSHOT version:

```bash
$WORKSHOP/release.sh 0
```

Now, move on to the second wave of projects.  First, you'll upgrade internal libraries to the newly released version:

```bash

mod run . --recipe org.openrewrite.java.dependencies.UpgradeDependencyVersion -P "groupId=com.example.ecom" -P "artifactId=*" -P "newVersion=1.x"

mod git apply . --last-recipe-run
```

Then you'll run the custom Spring Boot 4.0 upgrade recipe on Wave 2:

```bash
mod run $WORKSPACE --recipe org.openrewrite.recipe.querydsl.CustomUpgradeSpringBoot_4_0

mod git apply $WORKSPACE --last-recipe-run
```

Finally, test and release this just like the first wave:

```bash
$WORKSHOP/build.sh 1
$WORKSHOP/release.sh 1
```

Continue to upgrade all of your waves.








1. Apply the suggested changes to all projects: `mod git apply . --last-recipe-run `
1. Check to see if projects compile after the recipe: `mod exec . -- mvn clean package`
1. Rebuild the LSTs so they reflect the new changes and the mod CLI will detect the new Java versions: `mod build $WORKSPACE`
We can see that only a couple of our projects - some but not all of our shared libraries - successfully build now.

1. Next, we can try to do our migration in layers to get some iterative value and see where things break down:
    1. Upgrade build tools:
        - `mod run $WORKSPACE --recipe org.openrewrite.maven.UpdateMavenWrapper -P "wrapperVersion=3.3.4" -P "wrapperDistribution=script" -P "distributionVersion=3.9.11" -P "addIfMissing=true"`
        - Note that this doesn't seem to work correctly at the moment, only upgrading some repositories but not others.
    1. Upgrade test framework:
        - We know JUnit 6 requires a minimum of Java 17, so we can do JUnit 5 first so that we have a smaller changeset when we upgrade Java.
        - `mod run $WORKSPACE --recipe org.openrewrite.java.testing.junit5.JUnit5BestPractices`
        - `mod git apply . --last-recipe-run`
        - If we try to build everything now, we see this is broken in some projects because of `@RunWith(SpringJUnit4ClassRunner.class)`.  This tells us we probably should upgrade Spring _before_ upgrading JUnit.
    1. Spring Boot 2.7 has better support for modern Java versions including Java 17, so let's upgrade that first.
        - `mod run $WORKSPACE --recipe org.openrewrite.java.spring.boot2.UpgradeSpringBoot_2_7`
        - `mod git apply . --last-recipe-run`
        - If we build now, we see that some projects fail to build because of a removed spring-cloud-starter-zipkin dependency.  We can replace this dependency with it's new version.
    1. Replace the spring-cloud-starter-zipkin dependency with it's new version spring-cloud-sleuth-zipkin:
        - `mod run $WORKSPACE --recipe org.openrewrite.maven.ChangeDependencyGroupIdAndArtifactId -P "oldGroupId=org.springframework.cloud" -P "oldArtifactId=spring-cloud-starter-zipkin" -P "newGroupId=org.springframework.cloud" -P "newArtifactId=spring-cloud-sleuth-zipkin"`
        - `mod git apply . --last-recipe-run`
        - Test the build and this should still be building successfully.  3 projects should have updated as a result of this recipe.
    1. Go back and run the Spring Boot 2.7 upgrade again.  Apply and build it.  This should build now, and you've officially upgraded Spring Boot to 2.7.
    1. Next up, let's return to our JUnit upgrade.  Rerun and retest.  This should now pass because the upgrade to Spring Boot 2.7 removed the unneeded `@RunWith` annotation.  Now we've upgraded JUnit to 5.
    1. Although future migration recipes may fix the javax-to-jakarta migration, we can do this as another layer here:
        - `mod run $WORKSPACE --recipe org.openrewrite.java.migrate.jakarta.JakartaEE11`
        - `mod git apply . --last-recipe-run`
        - test build
    1. To go to Spring Boot 3.x onward or JUnit 6, we'll need to upgrade Java to 17 or higher.  Let's tackle that upgrade next, so that we're isolating those specific changes.
        - `mod run $WORKSPACE --recipe org.openrewrite.java.migrate.UpgradeToJava17`
        - `mod git apply . --last-recipe-run`
        - This should build successfully - we're up to a new version of Java!
    
    1. Alright, it feels like we're as ready as we can be to jump to Spring Boot 4.0.  Let's do that now:
        - `mod run $WORKSPACE --recipe org.openrewrite.java.spring.boot4.UpgradeSpringBoot_4_0`
        - `mod git apply . --last-recipe-run`
    
    
1. Let's run some migration planning recipes to see what we can learn:
    ```bash
    # DevCenterStarter
    mod run $WORKSPACE --recipe io.moderne.devcenter.DevCenterStarter
    mod devcenter . --last-recipe-run

    # PlanJavaMigration
    mod run $WORKSPACE --recipe org.openrewrite.java.migrate.search.PlanJavaMigration
    mod study $WORKSPACE --last-recipe-run --data-table JavaVersionMigrationPlan
    ```

    PlanJavaMigration gives us current Java version and if its a Gradle or Maven project.  I'm not sure there's a lot of actionable info here that should change out mind about approach, just situational awareness.

    Let's see if we can find which Spring Boot versions we're using:
    ```bash
    mod run $WORKSPACE --recipe org.openrewrite.java.dependencies.DependencyInsight -P "groupIdPattern=org.springframework.boot" -P "artifactIdPattern=spring-boot" -P "scope=runtime"
    ```
1. TODO: Find shared libraries or other kinds of dependencies across repositories
1. TODO: Find projects that are limited in the Java version they can use'





mod run $WORKSPACE --recipe org.openrewrite.maven.UpdateMavenWrapper -P "distributionVersion=3.9.11" -P "addIfMissing=true" -P "wrapperDistribution=script"