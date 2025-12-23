#!/usr/bin/env bash

export WORKSPACE=~/workspaces/migration_workshop
export WORKSHOP=~/projects/moderne-migration-practice
export PROJECTS=~/projects

cd $WORKSPACE
mod git sync csv $WORKSPACE $WORKSHOP/repos.csv --with-sources
tree -d $WORKSPACE -L 3
$WORKSHOP/release.sh
mod build $WORKSPACE
mod config recipes delete
mod config recipes jar install io.moderne.recipe:rewrite-spring:0.19.0 org.openrewrite.recipe:rewrite-migrate-java:3.24.0 org.openrewrite.recipe:rewrite-java-dependencies:1.48.0 org.openrewrite:rewrite-java:8.69.0 org.openrewrite:rewrite-maven:8.69.0 io.moderne.recipe:rewrite-devcenter:1.13.1 org.openrewrite.recipe:rewrite-spring:6.21.0 org.openrewrite.recipe:rewrite-testing-frameworks:3.24.0

mod run $WORKSPACE --recipe io.moderne.java.spring.boot4.UpgradeSpringBoot_4_0
mod git apply $WORKSPACE --last-recipe-run
$WORKSHOP/build.sh
mod exec $WORKSPACE git restore MODERNE_BUILD_TOOL_DIR
$WORKSHOP/build.sh # skip this?
mod build $WORKSPACE

mod run $WORKSPACE --recipe org.openrewrite.java.migrate.search.PlanJavaMigration
mod study $WORKSPACE --last-recipe-run --data-table JavaVersionMigrationPlan

mod run $WORKSPACE --recipe org.openrewrite.java.dependencies.DependencyInsight -P "groupIdPattern=org.springframework.boot" -P "artifactIdPattern=spring-boot" -P "scope=runtime"
mod study $WORKSPACE --last-recipe-run --data-table DependenciesInUse

mod run $WORKSPACE --recipe org.openrewrite.java.search.FindTypes -P "fullyQualifiedTypeName=javax..*"
mod study $WORKSPACE --last-recipe-run --data-table TypeUses

mod run $WORKSPACE --recipe org.openrewrite.maven.search.FindPlugin -P "groupId=com.mysema.maven" -P "artifactId=apt-maven-plugin"
mod study $WORKSPACE --last-recipe-run --data-table SourcesFileResults

mod run $WORKSPACE --recipe io.moderne.devcenter.DevCenterStarter
mod devcenter $WORKSPACE --last-recipe-run

cd $PROJECTS
git clone git@github.com:MBoegers/Release-Train-Metro-Plan.git
cd Release-Train-Metro-Plan
./gradlew clean publishToMavenLocal
mod config recipes jar install dev.mboegie.rewrite:release-train-metro-plan:0.1.0-SNAPSHOT
mod run $WORKSPACE --recipe dev.mboegie.rewrite.releasemetro.ReleaseMetroPlan --parallel

mod study $WORKSPACE --last-recipe-run --data-table ParentRelationships
mod study $WORKSPACE --last-recipe-run --data-table ProjectCoordinates
mod study $WORKSPACE --last-recipe-run --data-table UnusedDependencies
mod study $WORKSPACE --last-recipe-run --data-table DependenciesInUse


mod git sync csv $WORKSPACE $WORKSHOP/repos-waves.csv --with-sources
tree -d . -L 3

mod git checkout -b $WORKSPACE migration-workshop

$WORKSHOP/release.sh
mod build $WORKSPACE
mod exec $WORKSPACE -- git add -A
mod exec $WORKSPACE -- git commit -m "Initial release"

mod run $WORKSPACE --recipe org.openrewrite.maven.BestPractices
mod git apply $WORKSPACE --last-recipe-run
$WORKSHOP/build.sh
mod git add $WORKSPACE --last-recipe-run
mod git commit $WORKSPACE -m "Maven best practices" --last-recipe-run
mod build $WORKSPACE

mod run $WORKSPACE --recipe org.openrewrite.maven.ChangeDependencyGroupIdAndArtifactId -P "oldGroupId=org.springframework.cloud" -P "oldArtifactId=spring-cloud-starter-zipkin" -P "newGroupId=org.springframework.cloud" -P "newArtifactId=spring-cloud-sleuth-zipkin"
mod git apply . --last-recipe-run
$WORKSHOP/build.sh
mod git add $WORKSPACE --last-recipe-run
mod git commit $WORKSPACE -m "Change Spring Cloud Zipkin artifact ID" --last-recipe-run
mod build $WORKSPACE

mod run $WORKSPACE --recipe org.openrewrite.java.spring.boot2.UpgradeSpringBoot_2_7
mod git apply $WORKSPACE --last-recipe-run
$WORKSHOP/build.sh
mod git add $WORKSPACE --last-recipe-run
mod git commit $WORKSPACE -m "Upgrade to Spring Boot 2.7" --last-recipe-run
mod build $WORKSPACE

mod run $WORKSPACE --recipe org.openrewrite.java.migrate.UpgradeToJava8
mod git apply $WORKSPACE --last-recipe-run
$WORKSHOP/build.sh
mod git add $WORKSPACE --last-recipe-run
mod git commit $WORKSPACE -m "Upgrade to Java 8" --last-recipe-run
mod build $WORKSPACE

mod run $WORKSPACE --recipe org.openrewrite.java.migrate.UpgradeToJava17
mod git apply $WORKSPACE --last-recipe-run
$WORKSHOP/build.sh
mod git add $WORKSPACE --last-recipe-run
mod git commit $WORKSPACE -m "Upgrade to Java 17" --last-recipe-run
mod build $WORKSPACE

mod run $WORKSPACE --recipe org.openrewrite.java.testing.junit.JUnit6BestPractices 
mod git apply $WORKSPACE --last-recipe-run
$WORKSHOP/build.sh
mod git add $WORKSPACE --last-recipe-run
mod git commit $WORKSPACE -m "JUnit 6 best practices" --last-recipe-run
mod build $WORKSPACE

mod run $WORKSPACE --recipe io.moderne.java.spring.boot4.UpgradeSpringBoot_4_0
mod git apply $WORKSPACE --last-recipe-run

$WORKSHOP/build.sh 0 # succeeds
$WORKSHOP/build.sh 1 # fails

mod exec $WORKSPACE git restore MODERNE_BUILD_TOOL_DIR
$WORKSHOP/build.sh # succeeds (we're back to where we were before)
mod build $WORKSPACE

cd $PROJECTS 
git clone git@github.com:mtthwcmpbll/rewrite-querydsl.git
cd rewrite-querydsl
mvn clean install
mod config recipes jar install org.openrewrite.recipe:rewrite-querydsl:0.1.0-SNAPSHOT

cd $PROJECTS
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
mod config recipes yaml install CustomUpgradeSpringBoot_4_0.yml

mod run $WORKSPACE/Wave0 --recipe org.openrewrite.recipe.querydsl.CustomUpgradeSpringBoot_4_0
mod git apply $WORKSPACE/Wave0 --last-recipe-run
$WORKSHOP/build.sh 0
$WORKSHOP/release.sh 0

mod run $WORKSPACE/Wave1 --recipe org.openrewrite.recipe.querydsl.CustomUpgradeSpringBoot_4_0
mod git apply $WORKSPACE/Wave1 --last-recipe-run
$WORKSHOP/build.sh 1
$WORKSHOP/release.sh 1

mod run $WORKSPACE/Wave2 --recipe org.openrewrite.recipe.querydsl.CustomUpgradeSpringBoot_4_0
mod git apply $WORKSPACE/Wave2 --last-recipe-run
$WORKSHOP/build.sh 2
$WORKSHOP/release.sh 2

mod run $WORKSPACE/Wave3 --recipe org.openrewrite.recipe.querydsl.CustomUpgradeSpringBoot_4_0
mod git apply $WORKSPACE/Wave3 --last-recipe-run
$WORKSHOP/build.sh 3
$WORKSHOP/release.sh 3 # skip this?