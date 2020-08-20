#lang scribble/manual
@require[@for-label[racket/base]]

@title{racket-copilot}
@author{dmelcer9}

@section{Sequence diagrams with UML}

@subsection{Establishing a connection}

@verbatim{
 participant Client 1
 participant Client 2
 participant Server

 Client 1->Server: New session command
 Server->Client 1: New session info

 Client 2->Server: Join session command
 Server->Client 1: Other participant info
 Client 1->Server: Base document revision

 Server->Client 2: Other participant info
 Server->Client 2: Base document revision
 note over Client 2: Replaces text in current editor or opens new tab?\nEditor is read-only for either option.
}

@subsection{Regular communication}

@verbatim{
 participant Client 1
 participant Client 2
 participant Server

 Client 1->Server: Incremental revision

 note over Client 2: Background thread waits on TCP port for message
 Server->Client 2: Incremental revision
}

@subsection{Transfer control}

@verbatim{
 participant Client 1
 participant Client 2
 participant Server

 note over Client 1: Lock editor
 Client 1->Server: Transfer control command
 Server->Client 2: Transfer control info

 opt information out of sync
 Client 2->Server: Request base revision
 Server->Client 1: Request base revision
 Client 1->Server: Base revision
 Server->Client 2: Base revision
 end
}

@section{Messages}

@subsection{New session command}

@verbatim{
{
  "type": "new-session",
  "data": {
    "name": "Foo" // Username
  }
}
}

@subsection{New session info}

@verbatim{
{
  "type": "new-session-info",
  "data": {
    "userId": 123, // Sequential
    "sessionId": 123, // Sequential
    "password": "89XPYLKQWT" // Randomly generated server-side
  }
}
}

@subsection{Join session command}
@verbatim{
{
  "type": "join-session",
  "data": {
    "name": "Bar",
    "sessionId": 123,
    "password": "89XPYLKQWT"
  }
}
}

@subsection{Participant info}

@verbatim{
{
  "type": "participant-info",
  "data": {
    "you": {
      "name": "Foo",
      "userId": 123, 
    },
    "particpants": [{ // Other people (initially limited to one person, but this shouldn't be constrained)
      "name": "Baz",
      "userId": 123
    }]
  }
}
}

@subsection{Documents}

A document appears to be a series of snips. Even text is a snip, though if everything is too slow, text is a good candidate for special treatment.

@margin-note{Base64 was chosen because I don't want to spend a disproportionate amount of time writing message-parsing code, at the cost of making the messages 1.33x as large.}

A snip is:

@verbatim{
{
  "class": "wxtext", // Or any of the other ones
  "bytes": "V2hhdCBkaWQgeW91IGV4cGVjdD8="
}
}
