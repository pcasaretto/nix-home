---
description: Create a MerchantSubscriptions maintenance task using iterative TDD
argument-hint: <task_name> <description>
---

## CREATE MAINTENANCE TASK: $ARGUMENTS

Create a maintenance task using iterative Test-Driven Development (TDD). Every maintenance task has exactly two methods:

- `collection`: Returns the records to process
- `process`: Receives one record at a time and performs the operation

Follow TDD iteratively: Write ONE failing test → Implement minimal code → Run test → Repeat

### Step 1: Understand the Core Structure

Every maintenance task follows this structure:

```ruby
class TaskName < MaintenanceTasks::Task
  m_shard_task!  # or gcs_csv_collection for CSV input

  def collection
    # Returns ActiveRecord relation or collection
  end

  def process(record)
    # Operates on one record
    # Must return the record
  end
end
```

### Step 2: Gather Requirements

Ask the user:

1. What records need to be selected? (determines `collection`)
2. What changes to make to each record? (determines `process`)
3. Any edge cases or special conditions?

### Step 3: Iterative TDD for `collection` Method

#### 3.1 Create the test file

Create `components/billing/merchant_subscriptions/test/tasks/maintenance/[task_name]_test.rb`:

```ruby
# typed: true
# frozen_string_literal: true

require "test_helper"

module MerchantSubscriptions
  module Maintenance
    class [TaskName]Test < ActiveSupport::TestCase
      use_redis
      include Factories

      setup do
        @task = [TaskName].new
      end
    end
  end
end
```

#### 3.2 Write FIRST failing test for collection

**Test 1: Collection exists**

```ruby
test "#collection responds to the method" do
  assert_respond_to @task, :collection
end
```

Run: `dev test [test_file] -n "test_#collection_responds"`

#### 3.3 Implement minimal code to pass

Create `components/billing/merchant_subscriptions/app/tasks/merchant_subscriptions/maintenance/[task_name].rb`:

```ruby
# typed: true
# frozen_string_literal: true

module MerchantSubscriptions
  module Maintenance
    class [TaskName] < MaintenanceTasks::Task
      m_shard_task!

      def collection
        # Minimal implementation
      end
    end
  end
end
```

#### 3.4 Add next test for collection requirements

**Test 2: Collection returns correct type**

```ruby
test "#collection returns an ActiveRecord relation" do
  collection = @task.collection
  assert_kind_of ActiveRecord::Relation, collection
end
```

Update collection to return proper type:

```ruby
def collection
  CoreGeneral2::Product.none  # Start with empty relation
end
```

#### 3.5 Add test for actual filtering logic

**Test 3: Collection filters correctly**

```ruby
test "#collection includes products with specific internal names" do
  included = create(:core_general_2_plan, internal_name: "target_product")
  excluded = create(:core_general_2_plan, internal_name: "other_product")

  collection = @task.collection

  assert_includes collection, included
  refute_includes collection, excluded
end
```

Implement the actual logic:

```ruby
PRODUCT_NAMES = ["target_product"].freeze

def collection
  CoreGeneral2::Product.where(internal_name: PRODUCT_NAMES)
end
```

#### 3.6 Continue until collection is complete

Add tests for:

- Proper includes/joins to avoid N+1
- Correct scope (plans vs all products)
- Any special conditions

### Step 4: Iterative TDD for `process` Method

Only start this after collection is fully tested and working.

#### 4.1 Write FIRST failing test for process

**Test 1: Process exists and returns record**

```ruby
test "#process returns the processed record" do
  product = create(:core_general_2_plan, internal_name: "target_product")

  result = @task.process(product)

  assert_equal product, result
end
```

#### 4.2 Implement minimal process

```ruby
def process(record)
  record  # Just return it
end
```

#### 4.3 Add test for actual changes

**Test 2: Process makes expected change**

```ruby
test "#process updates the capability" do
  product = create(:core_general_2_plan, internal_name: "target_product")

  @task.process(product)

  assert_equal expected_value, product.reload.capabilities.your_field
end
```

Implement the change:

```ruby
def process(product)
  capabilities = product.capabilities
  capabilities.your_field = new_value
  product.capabilities = capabilities
  product.save!

  product
end
```

#### 4.4 Add idempotency test

**Test 3: Process is idempotent**

```ruby
test "#process is idempotent" do
  product = create(:core_general_2_plan)

  @task.process(product)
  first_run = product.reload.updated_at

  @task.process(product)
  second_run = product.reload.updated_at

  assert_equal first_run, second_run
end
```

Update process to be idempotent if needed.

### Step 5: Refactor Phase

After all tests pass:

1. Extract constants
2. Add private helper methods
3. Improve naming
4. Add error handling if needed

### Step 6: Integration Test (Optional)

Only after both methods work, add if needed:

```ruby
::MaintenanceTasksIntegrationTests.for(self)
```

### Common Patterns Reference

Based on 138 existing tasks in this component:

**Collection Patterns:**

- Products: `CoreGeneral2::Product.plans.all` (30%)
- Specific products: `CoreGeneral2::Product.where(internal_name: LIST)` (25%)
- Prices: `CoreGeneral2::Price.includes(:product)` (20%)
- CSV: Use `gcs_csv_collection` instead of `m_shard_task!` (15%)

**Process Patterns:**

- Capabilities: Update through assignment then `save!`
- Metadata: Use `create_with().find_or_create_by()`
- Direct updates: Use `update_column` to bypass validations
- Always return the record

### Tips for Iterative TDD

1. **One test at a time** - Don't write all tests upfront
2. **Minimal implementation** - Just enough to pass the current test
3. **Run frequently** - After each test/implementation pair
4. **Complete one method** - Finish collection before starting process
5. **Use stub_const** - For test constants to avoid production dependencies

### Running Tests

```bash
# Run single test by name
dev test [test_file] -n "test_name"

# Run all tests for the file
dev test [test_file]
```

### Notes

- Always use `m_shard_task!` except for CSV collections
- Include associations in collection to avoid N+1
- Process must return the record
- Test iteratively: one small piece at a time
