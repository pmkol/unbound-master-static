## Unbound Master Static Build
This project retrieves Unbound's master branch and performs static compilation to generate software builds on an ad-hoc basis.

To ensure that your workflow runs correctly, you must use the following parameters in the config.yaml file:

```
username: ""
chroot: ""
directory: ""
```
The parameter username must be empty.

It is recommended to install the application in the directory /usr/local/unbound.

Using these parameters ensures that the workflow correctly sets the username, chroot, and directory for the application, which are necessary for it to function properly. Additionally, installing the application in the recommended directory ensures that it is installed in a standard location and can be easily found by the system.

Make sure to properly format and structure the config.yaml file to ensure that it is properly interpreted by the workflow. You can consult the application's documentation or seek help from the community if you encounter any issues or have any questions.
