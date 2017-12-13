# OpenStack Hound Module

## Overview

Install and configure Hound.

Since indexing can take some time, the Apache host is setup to look
for a $docroot/reindex.lock file, and return a sensible 503
maintenance page.  An external script can manage this file as
reindexing takes place.
