#!/bin/bash

# Define a function to find the Magento root directory by checking current and parent directories
find_magento_root() {
    DIR="$PWD"
    while [ "$DIR" != "/" ]; do
        # Check if the directory contains a Magento installation
        if [ -f "$DIR/app/etc/env.php" ] || [ -f "$DIR/bin/magento" ]; then
            echo "$DIR"
            return 0
        fi
        # Move up one directory
        DIR=$(dirname "$DIR")
    done
    return 1 # Magento not found
}

# Call the function to find the Magento root
MAGENTO_DIR=$(find_magento_root)

# If a Magento installation is found, change to that directory
if [ -n "$MAGENTO_DIR" ]; then
    cd "$MAGENTO_DIR" || exit
    echo "Changed to Magento directory: $MAGENTO_DIR"
else
    echo "Magento installation not found in current or parent directories."
    exit 1
fi

# Define the help function
function show_help() {
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  --module     Run setup upgrade, compile DI, and clean/flush cache."
    echo "  --js         Clean preprocessed and static files, deploy static content, and clean/flush cache."
    echo "  --er         Restart Elasticsearch service and reindex."
    echo "  --complete   Run complete workflow: upgrade, compile, clean files, deploy static content, reindex, and clean/flush cache."
    echo "  --help       Show this help message."
    echo "  (No option)  Clean and flush cache only."
}

# Define the commands for each option
function run_module() {
    commands=(
        "php bin/magento setup:upgrade"
        "php bin/magento setup:di:compile"
        "php bin/magento cache:clean"
        "php bin/magento cache:flush"
    )
}

function run_js() {
    commands=(
        "rm -rf ./var/view_preprocessed/*"
        "rm -rf ./pub/static/frontend/*"
#        "php bin/magento setup:static-content:deploy -f"
        "php bin/magento cache:clean"
        "php bin/magento cache:flush"
    )
}

function run_complete() {
    commands=(
        "php bin/magento setup:upgrade"
        "php bin/magento setup:di:compile"
        "rm -rf ./var/view_preprocessed/*"
        "rm -rf ./pub/static/frontend/*"
        "php bin/magento setup:static-content:deploy -f"
        "php bin/magento indexer:reindex"
        "php bin/magento cache:clean"
        "php bin/magento cache:flush"
    )
}

function run_elastic_restart() {
    commands=(
        "sudo systemctl restart apache2"
	"sudo systemctl restart elasticsearch"
        "php bin/magento indexer:reindex catalog_product_price catalog_product_attribute cataloginventory_stock catalogrule_rule catalogrule_product"
    )
}

function run_default() {
    commands=(
        "php bin/magento cache:clean"
        "php bin/magento cache:flush"
    )
}

# Check the passed argument and execute corresponding commands
case "$1" in
    --module)
        run_module
        ;;
    --js)
        run_js
        ;;
    --complete)
        run_complete
        ;;
    --er)
        run_elastic_restart
        ;;
    --help)
        show_help
        exit 0
        ;;
    '')
        run_default
        ;;
    *)  echo -e "\e[31mCommand not found: use cl --help to see available options.\e[0m"
esac

# Execute each command
for command in "${commands[@]}"; do
    echo -e "\e[32mExecuting: $command\e[0m"
    $command
    if [ $? -ne 0 ]; then
        echo -e "\e[31mError: Command failed - $command\e[0m"
        exit 1
    fi
done

echo "All commands executed successfully."