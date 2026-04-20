## SQL Query Input
SQL Query problem 1-9 were pretty straight-forward.
For problem 10, :
1. Task is an independent dimension
2. Person is an independent identity
3. The task assignment to person has M:M (Many-to-Many) relationship
4. Since the task lives fluctuates over multiple status until it's considered done, these status neded to be tracked at each transition from one status to another. The task status track entity will record this change.

In order to improve and make this solution efficient,I added the below PROMPT to Claude SONNET 4.6 Model and it generated the Model in context to the problem definition/requirements provided in the PROMPT: