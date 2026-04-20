## Task Tracker Input
I initially broke down the problem into 4 different entities without the involvement of AI: person, task, task orchestration, and task status tracker and build initial data model around the problem. A few consideration regarding this solutions include:
1. Task is an independent dimension
2. Person is an independent identity
3. The task assignment to person has M:M (Many-to-Many) relationship
4. Since the task lives fluctuates over multiple status until it's considered done, these status neded to be tracked at each transition from one status to another. The task status track entity will record this change.

In order to improve and make this solution efficient,I added the below PROMPT to Claude SONNET 4.6 Model and it generated the Model in context to the problem definition/requirements provided in the PROMPT:
## PROMPT For Data Modeler

Act as a Senior Data Modeler. 
<context> Business rules: Create a model that allows people to track Tasks over time. People can be assigned to do a Task. A task can reoccur at a cadence of daily, weekly, monthly. Each occurrence of a task can have statuses: Not Started, In Progress, Completed (but not the Task itself) 
</context> 

<requirements>
Normalize to 3NF.
Use PostgreSQL syntax.
Include audit columns (created_on, updated_on).
Use Star Schema 
</requirements>
Make the generic Data Model around any person entity.

<output_format>
Table definitions with keys.
Brief justification for relationships.
An ER Model Diagram that clearly satisfy the above requirements 
</output_format>

Utilizing this PROMPT, the model generated ER Diagram with expected entities, in addition to date and status dimension. However, the FACT tables were missing the audit columns in the first attempt of the PROMPT as I didn't include them in the requirements but later on when I verified the schema, I improved the prompt to add those as part of requirements. This was the only thing missing in the first PROMPT.
The model also generated SEED input for the Diension tables which I am including in the DML Script.
Overall, it was good experience tackling this problem.