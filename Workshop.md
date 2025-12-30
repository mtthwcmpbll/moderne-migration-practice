# Moderne Migration Practice Environment

## Setup

> Note:  We'll use a couple of conventions in this document to refer to some common directories. `$WORKSHOP` will refer to the root of this repository. `$WORKSPACE` will refer to the directory you're cloning repos into and running `mod` commands against. `$PROJECTS` refers to a directory outside of `$WORKSPACE` where you can clone other repositories to work on separately. If you want to make this simpler and run commands copied directly from this workshop guide, you can use `export WORKSPACE=~/workspaces/migration_workshop`, `export WORKSHOP=~/projects/moderne-migration-practice`, and `export PROJECTS=~/projects` in your shell session. Replace the values of these variables with their real locations on your hard drive.

Let's start by using the Moderne CLI to clone all of our example repositories into an empty directory:

```bash
# Navigate to your empty workspace (make sure you've set `$WORKSPACE` in your shell previously, or just replace it with the actual place you want to go)
cd $WORKSPACE

# Clone all of our example repositories into the workspace with their source code so that we can apply suggested changes from recipes
# We will use this environment variable explicitly going forward so you can run `mod` commands from anywhere, but if you navigate to the `$WORKSPACE` path with the previous command and run `mod` from there, you can replace `$WORKSPACE` with `.` for future `mod` commands
mod git sync csv $WORKSPACE $WORKSHOP/repos.csv --with-sources
```

This `repos.csv` lists all of our example repositories, and you can view the final workspace structure to see that you have a directory for the GitHub org (or user) with the repositories inside:

```bash
tree -d $WORKSPACE. -L 3
```

This repository includes some helper scripts to run commands like testing, releasing, and doing common git actions across your repositories. The software development lifecycle of building and releasing new versions of these repositories is usually handled by your existing process outside of OpenRewrite and Moderne, but in this workshop you can simulate a release with the included `release.sh` script. Since all of our projects currently depend on a release version 1.0.0 of each other and those don't exist yet, go ahead and run a first release to get everything building:

```bash
# Release
$WORKSHOP/release.sh
```

This will automatically install the current non-SNAPSHOT version of each repository into your local Maven cache. It will then bump the project's version to the next available minor SNAPSHOT version, ready for you to make more changes.

Now we can build our first Lossless Semantic Trees (LSTs) so we can run OpenRewrite recipes on the synced repositories. This command may take a few minutes to run as it compiles the projects and builds the LSTs for each project:

```bash
# Build an LST for each project
mod build $WORKSPACE
```

To make sure we have all the OpenRewrite recipes we will need for this workshop, we can install the following recipe artifacts:

```bash
# For a deterministic workshop, this clears any installed recipes first
mod config recipes delete

# Install the necessary recipes for this workshop from the public Maven repository
mod config recipes jar install io.moderne.recipe:rewrite-spring:0.19.0 org.openrewrite.recipe:rewrite-migrate-java:3.24.0 org.openrewrite.recipe:rewrite-java-dependencies:1.48.0 org.openrewrite:rewrite-java:8.69.0 org.openrewrite:rewrite-maven:8.69.0 io.moderne.recipe:rewrite-devcenter:1.13.1 org.openrewrite.recipe:rewrite-spring:6.21.0 org.openrewrite.recipe:rewrite-testing-frameworks:3.24.0
```

## Step 0: Run the full migration

First up, you can always start by running the full migration recipe that we ultimately want to finish with. This often gives us some information on some of the obvious pitfalls that we might run into, including incompatible libraries or additional customizations that we need to make to the recipe. Go ahead and run the upgrade Spring Boot 4.0 recipe now:

```bash
# Run the recipe
mod run $WORKSPACE --recipe io.moderne.java.spring.boot4.UpgradeSpringBoot_4_0

# Apply the suggested changes to all projects
mod git apply . --last-recipe-run

# Build the projects to see if they compile
$WORKSHOP/build.sh
```

> Note: To ensure reproducible builds, projects refer to each other with specific release versions - not SNAPSHOTs or other dynamic references. This simulates an environment in a large organization where each of these repositories is owned by different teams and released independently. This probably isn't the case for _every_ repository in your portfolio - there's likely collections of related repositories that are all built and released together as a constellation of services. In our workshop, we'll simplify this to "every repository is independent from the others" to make sure we practice this particular speed bump.

Take a second to look at the output for the failed Maven builds. Why doesn't this work?

While every repository presents its own unique challenges, there are common speed bumps along the way that we can look for in any set of depositors. These include:

- Inconsistent or brittle build tool configuration
- Incompatible build tool versions (both the tools themselves and their plugins)
- Third-party dependencies that are incompatible with new versions of Java or upgraded frameworks
- Dependencies between repositories in the whole set that need to be built in order

In the example applications, we can see that there's actually a number of issues:

- We're failing to build some classes like `QOrder` and `QInventory`. These "Q" classes are coming from a code generator called QueryDSL, and code generators are a class of tools that are generally problematic during migrations. They often generate code that's specifically tuned for a particular version of Java or frameworks like Spring. Upgrading those runtimes often require an update to the code generator.
- We're seeing failures compiling test classes with errors like `package org.springframework.boot.test.autoconfigure.web.servlet does not exist`. Upgrading Spring also includes upgrading to a newer version of JUnit, so this might require us to update our tests, or we might be pulling in outdated testing libraries as dependencies.
- Errors like `'dependencies.dependency.version' for org.springframework.cloud:spring-cloud-starter-zipkin:jar is missing.` sounds like these used to be managed dependencies in our older Spring Boot versions but now there is no managed version specified in Spring Boot 4.0. This can happen when the dependency has move or been replaced by a different Spring Boot starter, or if the particular functionality was deprecated and removed.

### What makes a third-party library incompatible with newer versions of Java?

While you can run libraries compiled with an older version of Java in newer versions of JVM, the Java runtime has deprecated specific APIs and ultimately removed or refactored those as it has evolved. The major change that many people run into includes many `javax.*` internal APIs, including the Java EE APIs that were ultimately moved out of the JVM entirely and into the Jakarta namespace.

### Why do we care about dependencies between repositories as we're going through a migration?

Large organizations often have repositories that depend on each other, using internal shared libraries to share code and standardize specific functionality. These shared libraries can be owned, built, released, and versioned independently from the repositories that use them, so we need to upgrade these projects _and_ run them through their whole software developer lifecycle to release a new updated version that downstream consumers can move to. This can sometimes be as simple as upgrading a version number in a build manifest, or it can include complex code changes for those consumers to upgrade their code depending on how the libraries are built. 

Regardless, in order to upgrade all of our repositories, we often need to find the sets of repositories that are depended on and upgrade them first, then upgrade the rest in the proper sequence. For this workshop, we'll refer to each of these sets of repositories as "waves" of our migration.

We can use the Moderne CLI to apply any command across all of our repositories, including git commands. Go ahead and reset our repositories to a clean state now that we've learned from this experiment:

```bash
# Restore 
mod exec $WORKSPACE git restore MODERNE_BUILD_TOOL_DIR

# Rebuild the LST
$WORKSHOP/build.sh
mod build $WORKSPACE
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

Take a look at the CSV file reported in by that last command to see that we're using Java 8 and Maven across the board. In larger portfolios this can be helpful to locate groups of repositories that will take extra work to bring up to date, and can be an early warning signal pointed toward speed bumps your likely to encounter.

### DependencyInsight

Next up, let's check and see which versions of Spring Boot we're on:

```bash
mod run $WORKSPACE --recipe org.openrewrite.java.dependencies.DependencyInsight -P "groupIdPattern=org.springframework.boot" -P "artifactIdPattern=spring-boot" -P "scope=runtime"

# Extract a CSV data table containing our information
# Note: if you are prompted with multiple data table options with similar names, make sure to select the correct one (`org.openrewrite.maven.table.DependenciesInUse`)
> org.openrewrite.maven.table.DependenciesInUse
mod study $WORKSPACE --last-recipe-run --data-table DependenciesInUse
```

Looking at that data table should show that we're using a spread of Spring Boot 2.x versions.

### Find Types to Find common `javax.*` APIs

We know that many common `javax.*` APIs like JPA, validation, and servlet APIs moved to the Jarkarta namespace. Libraries and frameworks using the old packages can make it hard to upgrade to newer versions of Java. Let's find out if we're using any of those APIs:

```bash
# Run the recipe
mod run $WORKSPACE --recipe org.openrewrite.java.search.FindTypes -P "fullyQualifiedTypeName=javax..*"

# Extract a CSV data table containing our information
mod study $WORKSPACE --last-recipe-run --data-table TypeUses
```

This recipe shows that we're using the validation and persistence APIs, so we'll need to keep an eye on these and make sure that migration recipes upgrade to the new packages.

### Search for code generators with Find Plugins

We know that code generators can be a challenge when upgrading our repositories, and we know that we're using QueryDSL in some or all of these repositories. This tool uses a Maven plugin to generate its code, so we can find which projects are likely to need some extra effort upgrading this tool with the following:

```bash
# Run the recipe
mod run $WORKSPACE --recipe org.openrewrite.maven.search.FindPlugin -P "groupId=com.mysema.maven" -P "artifactId=apt-maven-plugin"

# Extract a CSV data table containing our information
mod study $WORKSPACE --last-recipe-run --data-table SourcesFileResults
```

This shows that four of our services are using QueryDSL as part of their persistence layer.

### DevCenter

Another great tool that can help us answer some of these questions and monitor our migration progress over time is the DevCenter. This is a special recipe that the Moderne CLI can use to build an HTML dashboard tracking our various migration goals. Let's build a devcenter for our repositories now:

```bash
# Run the recipe
mod run $WORKSPACE --recipe io.moderne.devcenter.DevCenterStarter

# Use the devcenter command to generate our dashboard
mod devcenter $WORKSPACE --last-recipe-run
```

Open up the HTML file provided in the output for that last command in a browser and you'll see visualizations for our 11 repositories showing which ones have been ugpraded to Java 25 and Spring Boot 4.0 (spoiler alert: none of them have been upgraded yet). We'll periodically rerun DevCenter as we go through this migration to see how this changes over time.

### Other useful code insight recipes for migration planning

- FindInternalJavaxApis filtering for our own base package `com.example.ecom.*` names will help find repositories that are using problematic Java APIs.
- FindDeprecatedUses will show if we're using any deprecated APIs or classes. If these are already deprecated in our current configuration, they may end up being removed in the version we're upgrade to.
- RelocatedDependencyCheck will help you find common dependencies that have been relocated to new groupId/artifactId coordinates in your dependency manager. It can also help change to the new coordinates, but it's a useful tool just to highlight libraries that have gone through changes between your current state and your target state.

## Step 2: Wave Planning

This is a special case of code insight - let's use the rich data we have in our LSTs about repository dependencies (direct _and_ transitive) to help us map our which of our repositories depend on each other. This should give us a list of repositories that don't depend on any others - this is our first wave that's save to upgrade now. Once we've upgraded this first wave, we'll need to release it and have our next wave (those repositories that depend on projects in the first wave) upgrade their dependencies to these new versions.

First things first, let's check out Merlin's metro mapping project to help us do the wave planning. Navigate to somewhere outside of your `$WORKSPACE`, clone the GitHub repository, and build and install the recipe artifact locally:

```bash
# Change to the projects directory outside of workspace
cd $PROJECTS

# Clone the repository - switch to HTTPS if you that's your preference here
git clone git@github.com:MBoegers/Release-Train-Metro-Plan.git

cd Release-Train-Metro-Plan

# Build the recipe artifact and install it into your local maven cache
./gradlew clean publishToMavenLocal

# Install the recipe artifact into your Moderne CLI from your maven cache
mod config recipes jar install dev.mboegie.rewrite:release-train-metro-plan:0.1.0-SNAPSHOT
```

You now have some new recipes available to your Moderne CLI. Let's use one of them to help us plan our upgrade waves:

```bash
mod run $WORKSPACE --recipe dev.mboegie.rewrite.releasemetro.ReleaseMetroPlan --parallel
```

This recipe will generate a bunch of CSV data tables and will output the list of them in the next steps section. Let's generate the handful we need:

```bash
mkdir $PROJECTS/data-tables

# Remember: if you are prompted with multiple data table options with similar names, make sure to select the correct one
mod study $WORKSPACE --last-recipe-run --data-table ParentRelationships --output-file $PROJECTS/data-tables/ParentRelationships.csv
mod study $WORKSPACE --last-recipe-run --data-table ProjectCoordinates  --output-file $PROJECTS/data-tables/ProjectCoordinates.csv
mod study $WORKSPACE --last-recipe-run --data-table UnusedDependencies  --output-file $PROJECTS/data-tables/UnusedDependencies.csv
mod study $WORKSPACE --last-recipe-run --data-table DependenciesInUse  --output-file $PROJECTS/data-tables/DependenciesInUse.csv
```

Each of these will output a path to a new CSV data table. You can use the Kotlin Jupyter notebook provided in the Release-Train-Metro-Plan repository to help you analyze the data in these tables and plan your upgrade waves.

Set the values for the various `val`s to the paths of the CSV data tables you just generated and run the notebook. Open the HTML file in that repo under `src/main/static/metro-plan.html` and you should see an interactive visualization based on the repository dependencies and, crucially, an ordered collection of waves:

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

With these waves identified, we need to do a little reorganization so that we can run recipes against the subset of repositories in a particular wave and then cut a new versioned release for downstream consumers to upgrade to. We can do this in a couple of ways:

1. You can create multiple `repos.csv` files, one for each wave. You can then `mod git sync csv` each wave into their own workspace to work on them in isolation.
2. You can manually navigate into each repository in a wave and run `mod` commands on just that one repository. This is manually intensive even at 11 repositories, and is untenable at scale. If you only have a few repositories, it can get the job done though.
3. You can use the organization structure feature of the `repos.csv` file to group repositories into waves. When you run `mod git sync csv` on a `repos.csv` with organization columns, it will automatically put those repositories into separate directories in your workspace. This allows you to dive into a specific wave's directory to run recipes against just those repositories, but lets you continue to run code insight and DevCenter recipes at the root of your workspace for a big picture view.

We'll use option 3 during this workshop. This repository provides a second file called `repos-waves.csv` and you can rerun the following in your workspace to reorganize it to include waves in the directory structure:

```bash
mod git sync csv $WORKSPACE $WORKSHOP/repos-waves.csv --with-sources
```

> Note: You may get a message stating `The directory currently represents the organization ε. Do you want to replace it [Yn]?`. This is just saying that your workspace already has an unnamed root organization checked out, and you'll be replacing it with the new organization structure. You can safely hit `Y` to process and it will delete the existing repositories in your workspace and reclone them into the new hierarchy.

Check out your new structure:

```bash
tree -d . -L 3
```

Alright, we're ready to start making actual changes to our repositories!

## Step 3: Level-Set Your Baseline

> Optional step:  You can use the Moderne CLI to checkout a new branch in all of the repositories if you want to commit changes step by step: `mod git checkout -b $WORKSPACE migration-workshop`.

Just like last time we synced a CSV, we need to run an initial release and build our LSTs to start:

```bash
$WORKSHOP/release.sh
mod build $WORKSPACE
```

Whether you checked out a separate branch or not, we'll be adding and committing our changes from here on out so that we have good restore points and so we have a good record of what has changed and which recipe made the changes. Let's commit our initial release:

```bash
mod exec $WORKSPACE -- git add -A
mod exec $WORKSPACE -- git commit -m "Initial release"
```

For some upgrades, it's often helpful to run the upgrade recipes for the language and frameworks we _think_ we're already running. This gives us a common baseline to start building on top of, instead of having many different flavors of "Spring 2.x" or "Maven projects".

```bash
# Run the recipe
mod run $WORKSPACE --recipe org.openrewrite.maven.BestPractices

# Apply the changes from the recipe
mod git apply . --last-recipe-run

# Test that everything still builds correctly after our changes
$WORKSHOP/build.sh

# Commit our changes if everything works
mod git add $WORKSPACE --last-recipe-run
mod git commit $WORKSPACE -m "Maven best practices" --last-recipe-run

# Rebuild the LSTs to match the new state of the codebase
mod build $WORKSPACE
```

> Note: Notice we are running `build.sh` (which runs `mvn clean install`) to verify things compile, then committing our changes as mentioned above, then using `mod build` to rebuild the LSTs. At a minimum, the `mod build` step is required to be run after each recipe, but we will include all of these steps after each recipe run for consistency.

This should build successfully. Since we're on a variety of Spring Boot 2.x versions, let's also run the recipe to upgrade to Spring Boot 2.7 since that includes better support for Java 17+, newer testing frameworks, etc. But first, we know from our earlier code insight that we're using a dependency `spring-cloud-starter-zipkin` which is no longer supported, so let's run a recipe to change it to the new correct dependency to avoid Spring Boot 2.7 complaining at us:

```bash
# Run the recipe to change a dependency's artifactId
mod run . --recipe org.openrewrite.maven.ChangeDependencyGroupIdAndArtifactId -P "oldGroupId=org.springframework.cloud" -P "oldArtifactId=spring-cloud-starter-zipkin" -P "newGroupId=org.springframework.cloud" -P "newArtifactId=spring-cloud-sleuth-zipkin"

# Apply the changes from the recipe
mod git apply . --last-recipe-run

# Test that everything still builds correctly after our changes
$WORKSHOP/build.sh

# Commit our changes if everything works
mod git add $WORKSPACE --last-recipe-run
mod git commit $WORKSPACE -m "Change Spring Cloud Zipkin artifact ID" --last-recipe-run

# Rebuild the LSTs to match the new state of the codebase
mod build $WORKSPACE
```

Now let's upgrade our baseline to Spring Boot 2.7:

```bash
# Run the recipe
mod run $WORKSPACE --recipe org.openrewrite.java.spring.boot2.UpgradeSpringBoot_2_7

# Apply the changes from the recipe
mod git apply . --last-recipe-run

# Test that everything still builds correctly after our changes
$WORKSHOP/build.sh

# Commit our changes if everything works
mod git add $WORKSPACE --last-recipe-run
mod git commit $WORKSPACE -m "Upgrade to Spring Boot 2.7" --last-recipe-run

# Rebuild the LSTs to match the new state of the codebase
mod build $WORKSPACE
```

Let's do the same thing for our Java version - we're on Java 8, so let's make sure we're following the best practices for this version of Java as a starting point:

```bash
# Run the recipe
mod run $WORKSPACE --recipe org.openrewrite.java.migrate.UpgradeToJava8

# Apply the changes from the recipe
mod git apply . --last-recipe-run

# Test that everything still builds correctly after our changes
$WORKSHOP/build.sh

# Commit our changes if everything works
mod git add $WORKSPACE --last-recipe-run
mod git commit $WORKSPACE -m "Upgrade to Java 8" --last-recipe-run

# Rebuild the LSTs to match the new state of the codebase
mod build $WORKSPACE
```

Everything up until this point should be build successfully so far, and we're now at a common baseline across the repositories.

## Step 4: Our first major upgrade

We could try upgrading Spring Boot to 4.0 now, but that might still be a larger changeset with many speed bumps between us and a successful release of some new value. Let's start with a much smaller change and upgrade our Java to 17, since we know that's a prerequisite for JUnit 6 and Spring Boot 3.x.

> We can't upgrade to Java 25 yet because it wasn't released when Spring Boot 2.7 was most recently released, so those dependencies are incompatible with Java 25's class file format. Give it a try and see what happens with `mod run . --recipe org.openrewrite.java.migrate.UpgradeToJava25`

Run the upgrade to Java 17:

```bash
# Run the recipe
mod run $WORKSPACE --recipe org.openrewrite.java.migrate.UpgradeToJava17

# Apply the changes from the recipe
mod git apply . --last-recipe-run

# Test that everything still builds correctly after our changes
$WORKSHOP/build.sh

# Commit our changes if everything works
mod git add $WORKSPACE --last-recipe-run
mod git commit $WORKSPACE -m "Upgrade to Java 17" --last-recipe-run

# Rebuild the LSTs to match the new state of the codebase
mod build $WORKSPACE
```

The Spring Boot 4.0 upgrade recipe will upgrade to newer versions of JUnit too, but changing your test framework and changing your Spring application logic can be very different kinds of updates. Every iteration of our migration that we can build and push raises the water line for all of our repositories and makes future migration changesets easier to review and promote to production releases because they're smaller and more focused. Let's upgrade to JUnit 6 next so that we case focus on test dependencies and libraries separately from our application code:

```bash
# Run the recipe
mod run $WORKSPACE --recipe org.openrewrite.java.testing.junit.JUnit6BestPractices 

# Apply the changes from the recipe
mod git apply . --last-recipe-run

# Test that everything still builds correctly after our changes
$WORKSHOP/build.sh

# Commit our changes if everything works
mod git add $WORKSPACE --last-recipe-run
mod git commit $WORKSPACE -m "JUnit 6 best practices" --last-recipe-run

# Rebuild the LSTs to match the new state of the codebase
mod build $WORKSPACE
```

Finally, let's upgrade to Spring Boot 4.0:

```bash
# Run the recipe
mod run $WORKSPACE --recipe io.moderne.java.spring.boot4.UpgradeSpringBoot_4_0

# Apply the changes from the recipe
mod git apply $WORKSPACE --last-recipe-run
```

Up until this point, we've been running recipes against the entire workspace. Applying the changes to any given repository hasn't been _incompatible_ with the old released versions of the internal shared libraries still being used across the codebase. The Spring Boot 4.0 upgrade is different though, and you should be seeing build failures in some projects. The `build.sh` script takes a parameter specifying the wave to build so that you can build specific waves and narrow in on problems. Let's build Wave 0 first:

```bash
$WORKSHOP/build.sh 0
```

Wave 0 builds fine (it's only one project with no internal dependencies after all!). Now we can try Wave 1:

```bash
$WORKSHOP/build.sh 1
```

Some projects in this wave fail due to the incompatible QueryDSL code generator library. We'll have to deal with that next, but first, let's restore our code back to the last working state:

```bash
# Restore to the previous commit
mod exec $WORKSPACE git restore MODERNE_BUILD_TOOL_DIR

# Now this should build successfully and rebuild the LSTs
$WORKSHOP/build.sh
mod build $WORKSPACE
```

## Step 5: Upgrading QueryDSL

You'll often run into third-party libraries that you're using that need some code changes to upgrade above and beyond just bumping a dependency version to a newer release. QueryDSL 3.x generates classes using the outdated `javax.*` namespaces, but it's also gone through some restructuring in newer releases that have changed package names and APIs. This is a good example of running into a speed bump that will require you to write a custom recipe to get past. In this case, custom recipe authorship is outside the scope of this workshop so [we've written one for you](https://github.com/mtthwcmpbll/rewrite-querydsl). Similar to the Release-Train-Metro-Plan earlier, you'll need to clone this repository and build and install it locall to use it in the Moderne CLI:

```bash
# Change to projects directory outside of workspace
cd $PROJECTS

# Clone the recipe project, build, and install it
git clone git@github.com:mtthwcmpbll/rewrite-querydsl.git
cd rewrite-querydsl
mvn clean install
mod config recipes jar install org.openrewrite.recipe:rewrite-querydsl:0.1.0-SNAPSHOT
```

This new project introduces a custom recipe `org.openrewrite.recipe.querydsl.UpgradeToQueryDsl5` that renames packages, changes dependencies, and updates APIs to move from QueryDSL 3.x to QueryDSL 5.x as it's used in these examples.

There's a chicken-and-egg problem here though - newer versions of QueryDSL require Spring Boot 3+ that has moved to the new `jakarta.*` namespace, but we can't run the Spring Boot upgrade because it will fail to compile the older QueryDSL generated code. We need to do both of these at the same time.

This is an example of a migration recipe _freight train_ - you'll often build a custom recipe that runs the out-of-the-box recipes and then applies some additional ones that are needed in your particular environment. As you try migrating new repositories you'll find additional speed bumps that will drive you to enhance your custom recipes to move forward for more and more teams. You build momentum while you're running migrations and enhancing your custom recipes to make it turn-key for more and more repositories. 

Additionally, since we will be upgrading in waves to ensure our custom library dependencies are handled in the proper sequence, we need to make sure to update our dependency versions in each wave to use the newly released version from the previous wave. We will want to do this at the same time as well, so we can include it in our custom recipe too.

We'll need to create a custom recipe that combines the Spring Boot 4.0 upgrade, our QueryDSL upgrade recipes, and the release dependency bumps into a single recipe. We can do that using a declarative YAML recipe that strings them together in the correct sequence:

```bash
# Change to project directory outside of workspace
cd $PROJECTS

# Use this command to create a YAML file containing the combined recipe (or use your favorite text editor to do the same)
cat <<EOF > CustomUpgradeSpringBoot_4_0.yml
---
type: specs.openrewrite.org/v1beta/recipe
name: org.openrewrite.recipe.custom.MigrateJackson2JsonMessageConverter
displayName: Migrate Jackson2JsonMessageConverter to JacksonJsonMessageConverter
description: "Migrates from Jackson2JsonMessageConverter (Jackson 2) to JacksonJsonMessageConverter (Jackson 3) for Spring Boot 4.x"
recipeList:
  - org.openrewrite.java.ChangeType:
      oldFullyQualifiedTypeName: org.springframework.amqp.support.converter.Jackson2JsonMessageConverter
      newFullyQualifiedTypeName: org.springframework.amqp.support.converter.JacksonJsonMessageConverter
---
type: specs.openrewrite.org/v1beta/recipe
name: org.openrewrite.recipe.custom.UpgradeSpringCloud_2025_1
displayName: Upgrade to Spring Cloud 2025.1
description: Upgrade Spring Cloud from 2025.0.x to 2025.1.x for Spring Boot 4 compatibility
recipeList:
  - org.openrewrite.maven.ChangePropertyValue:
      key: spring-cloud.version
      newValue: "2025.1.0"
---
type: specs.openrewrite.org/v1beta/recipe
name: org.openrewrite.recipe.querydsl.CustomUpgradeSpringBoot_4_0
displayName: CustomUpgradeSpringBoot_4_0
description: ""
recipeList:
  - org.openrewrite.java.dependencies.UpgradeDependencyVersion:
      groupId: com.example.ecom
      artifactId: "*"
      newVersion: 1.x
  - org.openrewrite.recipe.querydsl.UpgradeToQueryDsl5
  - org.openrewrite.recipe.custom.MigrateJackson2JsonMessageConverter
  - org.openrewrite.recipe.custom.UpgradeSpringCloud_2025_1
  - io.moderne.java.spring.boot4.UpgradeSpringBoot_4_0

EOF

# Install your new custom recipe
mod config recipes yaml install CustomUpgradeSpringBoot_4_0.yml

```

Now let's run that recipe for the first wave and apply the changes:

```bash
mod run $WORKSPACE/Wave0 --recipe org.openrewrite.recipe.querydsl.CustomUpgradeSpringBoot_4_0

mod git apply $WORKSPACE/Wave0 --last-recipe-run
```

Test that this builds successfully:

```bash
$WORKSHOP/build.sh 0
```

If this build successfully, release this wave of projects by building a release artifact and incrementing to the next SNAPSHOT version:

```bash
$WORKSHOP/release.sh 0
```

Now, do the same for the next wave of projects:

```bash
mod run $WORKSPACE/Wave1 --recipe org.openrewrite.recipe.querydsl.CustomUpgradeSpringBoot_4_0

mod git apply $WORKSPACE/Wave1 --last-recipe-run
```

Finally, test and release this just like the first wave:

```bash
$WORKSHOP/build.sh 1
$WORKSHOP/release.sh 1
```

Continue to upgrade all of your waves sequentially in this fashion.