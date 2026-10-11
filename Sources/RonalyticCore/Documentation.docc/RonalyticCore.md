# ``RonalyticCore``

A small, modular analytics SDK. Track once, send anywhere.

## Overview

Ronalytic keeps events in a persistent queue, sends them in batches with retry,
and lets you add destinations (Firebase, Amplitude, console) as plugins.
Swapping a vendor means changing one line in the plugin list.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:DeliveryGuarantees>
- ``RonalyticClient``
- ``RonalyticSDK``
- ``RonalyticConfig``

### Extending

- ``Plugin``
- ``Event``
- ``PropertyValue``

### Storage and sending

- ``QueueStorage``
- ``Transport``
- ``DeliveryResult``
- ``BackoffPolicy``

### Privacy

- ``ConsentProvider``
- ``RedactionRule``
- ``OptOutStore``

### Diagnostics

- ``MetricsSnapshot``
- ``SDKLogger``
