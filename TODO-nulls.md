I can pass in:

```
PostReport.new(
  dimensions: {
    created_at: {
      only: { min: "null", max: "null" }
    },
    author: {
      only: "null"
    }
  }
)
```

- If the form asks for attributes, it should return what's in the params.
- The SQL query should use treat them as if they were nil.
- The values in the SQL output should be mapped back to "null".

Dimension#null_proxy

Useful because it's confusing when it's necessary to distinguish between a form sending blank values and not sending values at all. It's also sometimes a good pattern to have an explicit null.

Can change null_proxy back to nil if needed?

{ min: "null", max: "null" } vs. just "null"
oof.

NullBin?
behaves like string "null"
but responds to min/max with "null"

Also, auto-i18n?

Nulls should only be included in grouper values for bin dimensions if it's in the data
