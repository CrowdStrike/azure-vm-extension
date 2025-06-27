# Frequently Asked Questions (FAQs)

### Can I change sensor settings after installation?

Currently, the extension does not support modifying sensor settings after installation. This means that once the sensor is installed with specific configuration parameters (such as tags or proxy settings) through the extension's configuration JSON, you would need to uninstall and reinstall the extension with the new configuration to change these settings. This is because of the sensor's tamper and uninstall protection mechanisms require a maintenance token to modify or uninstall it after installation.s.

### Can I install the extension without adding the Sensor Update Policy - Write scope to my Oauth token?

The `Sensor Update Policy - Write` scope is only required if you are attempting to uninstall the sensor. If you are only installing the sensor, you do not need to add this scope to your OAuth token. 
