racket-copilot
==============

- common/
  - edit-events: Represent incremental edits and apply these edits to the editor
  - json-port-channel: Convert a port recieving JSON into a channel of js-exprs
  - messages: Messages between client and server
  - serialization: Common interfaces
  - snip-data: Serialize and deserialize snips

TODO

- Figure out how to properly structure docs and tests so raco works better
- Implement structs in common/messages.rkt - Done
- Implement classes in common/edit-events.rkt - Needs manual testing
- Decide on msgpack vs json
- Implement (de)serializer between messages.rkt and js-expr (or msgpack equivalent)
- Implement (de)serializer between js-expr and port/channel
- Write server for one session - Done
- Write server for multiple sessions
- Write client (run in own thread and accept messages from GUI)
- Create editor program with GUI toolkit
- Rewrite tool.rkt to use DrRacket instead of separate editor program (currently not included in repo because it's mostly LGPL example code)
