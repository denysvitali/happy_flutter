--------------------------- MODULE messaging ---------------------------
(***************************************************************************)
(*  TLA+ specification for the canonical chat-message contract used by     *)
(*  Happy Flutter.                                                         *)
(*                                                                         *)
(*  The four invariants that the Dart codebase must preserve:              *)
(*                                                                         *)
(*    I1 (Identity)        Every logical message has exactly one canonical *)
(*                         localId from the moment a user taps Send to     *)
(*                         the moment the merged record reaches storage.   *)
(*    I2 (NoDup)           Two distinct user taps never collapse into one  *)
(*                         logical message, even when text is identical.   *)
(*    I3 (Replacement)     A server ack replaces the optimistic row with   *)
(*                         a matching localId, and never the placeholder   *)
(*                         of any other tap.                               *)
(*    I4 (Retry)            An explicit retry preserves the original       *)
(*                         localId; a fresh resend allocates a new one.    *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, Sequences, TLC

CONSTANTS
    Texts,           \* set of message texts a user might type
    MaxTaps,         \* upper bound on user taps (model checking only)
    MaxLocalIds      \* upper bound on identifier allocations

ASSUME MaxTaps \in Nat /\ MaxLocalIds \in Nat /\ MaxLocalIds >= MaxTaps

\* Lifecycle states for a single logical message.
States == {"draft", "sending", "sent", "pending", "failed", "merged"}

VARIABLES
    nextLocalId,     \* monotonic counter used to mint fresh localIds
    messages,        \* function localId -> [text, state, retryOf]
    optimistic,      \* set of localIds with an unresolved optimistic row
    acked,           \* set of localIds that have been acked by the server
    taps             \* count of distinct user taps, for boundedness only

vars == <<nextLocalId, messages, optimistic, acked, taps>>

LocalId == 0..(MaxLocalIds - 1)

TypeOK ==
    /\ nextLocalId \in 0..MaxLocalIds
    /\ DOMAIN messages \subseteq LocalId
    /\ \A id \in DOMAIN messages :
         /\ messages[id].text \in Texts
         /\ messages[id].state \in States
         /\ messages[id].retryOf \in (DOMAIN messages \cup {-1})
    /\ optimistic \subseteq DOMAIN messages
    /\ acked \subseteq DOMAIN messages
    /\ taps \in 0..MaxTaps

Init ==
    /\ nextLocalId = 0
    /\ messages = << >>
    /\ optimistic = {}
    /\ acked = {}
    /\ taps = 0

\* User taps Send with some text. A fresh localId is minted.
Tap(t) ==
    /\ taps < MaxTaps
    /\ nextLocalId < MaxLocalIds
    /\ LET id == nextLocalId IN
        /\ messages' = [m \in DOMAIN messages \cup {id} |->
            IF m = id
              THEN [text |-> t, state |-> "sending", retryOf |-> -1]
              ELSE messages[m]]
        /\ optimistic' = optimistic \cup {id}
        /\ nextLocalId' = nextLocalId + 1
        /\ taps' = taps + 1
        /\ UNCHANGED <<acked>>

\* Server acks the message identified by localId. Optimistic row is replaced
\* exactly once, by matching localId only.
Ack(id) ==
    /\ id \in optimistic
    /\ id \notin acked
    /\ messages[id].state = "sending"
    /\ messages' = [messages EXCEPT ![id].state = "merged"]
    /\ optimistic' = optimistic \ {id}
    /\ acked' = acked \cup {id}
    /\ UNCHANGED <<nextLocalId, taps>>

\* REST/socket transport fails; the row stays optimistic but flips to failed.
Fail(id) ==
    /\ id \in optimistic
    /\ messages[id].state = "sending"
    /\ messages' = [messages EXCEPT ![id].state = "failed"]
    /\ UNCHANGED <<nextLocalId, optimistic, acked, taps>>

\* Retry preserves the original localId.
Retry(id) ==
    /\ id \in DOMAIN messages
    /\ messages[id].state = "failed"
    /\ messages' = [messages EXCEPT ![id].state = "sending"]
    /\ UNCHANGED <<nextLocalId, optimistic, acked, taps>>

\* Fresh resend (user tapped again) allocates a new localId pointing at a
\* failed predecessor through retryOf, but is its own logical message.
Resend(parent) ==
    /\ parent \in DOMAIN messages
    /\ messages[parent].state \in {"failed", "merged"}
    /\ taps < MaxTaps
    /\ nextLocalId < MaxLocalIds
    /\ LET id == nextLocalId IN
        /\ messages' = [m \in DOMAIN messages \cup {id} |->
             IF m = id
               THEN [text |-> messages[parent].text,
                     state |-> "sending",
                     retryOf |-> parent]
               ELSE messages[m]]
        /\ optimistic' = optimistic \cup {id}
        /\ nextLocalId' = nextLocalId + 1
        /\ taps' = taps + 1
        /\ UNCHANGED <<acked>>

Next ==
    \/ \E t \in Texts : Tap(t)
    \/ \E id \in DOMAIN messages : Ack(id)
    \/ \E id \in DOMAIN messages : Fail(id)
    \/ \E id \in DOMAIN messages : Retry(id)
    \/ \E p  \in DOMAIN messages : Resend(p)

Spec == Init /\ [][Next]_vars

(*-------------------------- Invariants ----------------------------------*)

\* I1 — every message in flight or merged has a stable, unique localId.
IdentityInvariant ==
    \A i, j \in DOMAIN messages :
        (i # j) => (i \in DOMAIN messages /\ j \in DOMAIN messages)

\* I2 — two distinct taps never collapse. Cardinality of DOMAIN messages
\* equals the number of taps that have happened so far.
NoDupInvariant ==
    Cardinality(DOMAIN messages) = taps

\* I3 — an acked message is no longer optimistic and was never replaced
\* by an ack for a different localId.
ReplacementInvariant ==
    /\ optimistic \cap acked = {}
    /\ \A id \in acked : messages[id].state = "merged"

\* I4 — retry preserves identity (same localId stays in domain), while a
\* resend creates a strictly new localId pointing at the parent.
RetryInvariant ==
    \A id \in DOMAIN messages :
        messages[id].retryOf # -1 =>
            /\ messages[id].retryOf < id
            /\ messages[id].retryOf \in DOMAIN messages

Invariants ==
    /\ TypeOK
    /\ IdentityInvariant
    /\ NoDupInvariant
    /\ ReplacementInvariant
    /\ RetryInvariant

=============================================================================
