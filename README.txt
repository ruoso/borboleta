Borboleta
---------

About the game
==============

This is an adventure game proposed by my 4yo son, the story goes as:

  "The butterfly first gets stuck in the spider web, then when he gets
  off it decides to go to space, where it has to run away from
  aliens. After it runs away from all the aliens, it decides to go
  home"

The gameplay is heavily inspired by Super Mario, in which it is a
side-scrolling arcade with different worlds and levels.

Code Architecture
=================

The first level of abstraction is the "mode". They represent the
different states of navigation in the game, specifically:

 * Main menu system
 * World Selection
 * World-selection menu system
 * Level Selection
 * Level-selection menu system
 * Level
 * In-level menu system
 
 Each mode is a self-contained application that takes over the main
 event loop of the game, but the data that is global is the
 "last-tick", such that when the game is unpaused, the mode that takes
 over doesn't see a huge jump in time.

Each mode is implemented in terms of a Model, a View and a
Controller. The Model represents the data for the Actor and implements
the hooks necessary for the "Observer Pattern" to be implemented.

The Model:

The Model works in a separate thread and will receive and respond to
message calls from the controller and will notify the view as well
about any changes.  Interactions between different model objects (such
as collision) also generate events. The "Model Manager" keeps track
of all model objects and manages the message queue for messages.

The View:

The view runs in a specific thread and a "View Manager" that knows
about view objects created in a particular mode, the "View Manager"
maintains the "Render Loop" for the view objects as well as receive
the messages that communicate changes in the model.

The Controller:

The controller consumes input events and notify the model in a
higher-level of the state of the input.
