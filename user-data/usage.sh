# Provide no arguments (defaults: ubuntu, 8G, no hostname change)
./cyberitex-setup.sh

# Provide only a custom user
./cyberitex-setup.sh alex

# Provide a custom user and 16G for swap
./cyberitex-setup.sh alex 16G

# Provide a custom user, 16G for swap, and set the system hostname to "hosting.cyberitex.com"
./cyberitex-setup.sh root 8G hosting.cyberitex.com
