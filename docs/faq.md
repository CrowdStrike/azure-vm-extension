# Frequently Asked Questions (FAQs)

### Can I change sensor settings after installation?

Currently, the extension does not support modifying sensor settings after installation. This means that once the sensor is installed with specific configuration parameters (such as tags or proxy settings) through the extension's configuration JSON, you would need to uninstall and reinstall the extension with the new configuration to change these settings. This is because of the sensor's tamper and uninstall protection mechanisms require a maintenance token to modify or uninstall it after installation.s.

### Can I install the extension without adding the Sensor Update Policy - Write scope to my Oauth token?

The `Sensor Update Policy - Write` scope is only required if you are attempting to uninstall the sensor. If you are only installing the sensor, you do not need to add this scope to your OAuth token. 

### How can I apply a maintenance token for uninstallation?

Providing a maintenance token for uninstallation is done by adding `Sensor Update Policy - Write` scope to your OAuth token. This allows the extension to properly uninstall the sensor by temporarily disabling tamper protection. Without this scope, uninstallation attempts will fail due to the sensor's built-in protection mechanisms. Alternatively, you can move the hosts to a different sensor update policy that has tamper and uninstall protection disabled.

### Why can't I provide a maintenance token to the extension's settings?

For security reasons, the extension does not accept maintenance tokens as direct parameters in its settings. This design choice prevents maintenance tokens from being stored in configuration files or appearing in logs, which could create security vulnerabilities. Instead, the extension obtains the necessary permissions through the OAuth token with the appropriate scope when uninstallation is requested. Alternatively, you can move the hosts to a different sensor update policy that has tamper and uninstall protection disabled.

### The installation of the extension is being killed by the operating system's out-of-memory (OOM) killer. What can I do?

This typically happens on VMs with limited memory resources. To resolve this issue, you should increase the VM's memory allocation if possible or use a different VM size with more memory.
