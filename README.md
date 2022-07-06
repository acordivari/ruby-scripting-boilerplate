# ruby scripting boilerplate

A simple scaffold for scripting.

I've personally recreated this and used many variations over my last
few jobs and figured it was worth overdue to create some boilerplate.

* Set a target URL or endpoint
* Configure an authentication protocol if there is one
* Set request headers
* Currently configured to accept a CSV input file.
* The script will loop over the rows, each row represents a different request (in this case a GET request).
* Currently set up to dump results to an output file,
can add a rescue for more granular error handling/logging
