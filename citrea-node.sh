#!/bin/bash

echo "Installing required packages..."
sudo apt install curl docker.io docker-compose jq -y

# Start Docker service
echo "Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Check Docker service status
if ! sudo systemctl is-active --quiet docker; then
    echo "Error: Docker service is not running. Please check 'systemctl status docker' for details."
    exit 1
fi

# Add current user to docker group
sudo usermod -aG docker $USER

BASE_DIR="$HOME/citrea-node"
INITIAL_DIR=$(pwd)

install_default() {
    if [ -d "$BASE_DIR" ]; then
        echo "Citrea node is already installed! Please uninstall it first."
        return
    fi

    echo "Installing Citrea node with default settings..."
    mkdir -p $BASE_DIR && cd $BASE_DIR
    curl https://raw.githubusercontent.com/chainwayxyz/citrea/refs/heads/nightly/docker/docker-compose.yml --output docker-compose.yml
    docker-compose up -d
    echo "Default installation completed!"
    cd $INITIAL_DIR
}

install_custom() {
    if [ -d "$BASE_DIR" ]; then
        echo "Citrea node is already installed! Please uninstall it first."
        return
    fi

    echo "Installing Citrea node with custom settings..."
    
    read -p "Enter new RPC username (default: citrea): " rpc_user
    rpc_user=${rpc_user:-citrea}
    
    read -p "Enter new RPC password (default: citrea): " rpc_password
    rpc_password=${rpc_password:-citrea}
    
    read -p "Enter new RPC port (default: 8080): " rpc_port
    rpc_port=${rpc_port:-8080}
    
    mkdir -p $BASE_DIR && cd $BASE_DIR
    
    curl https://raw.githubusercontent.com/chainwayxyz/citrea/refs/heads/nightly/docker/docker-compose.yml --output docker-compose.yml
    
    sed -i "s/-rpcuser=citrea/-rpcuser=$rpc_user/" docker-compose.yml
    sed -i "s/-rpcpassword=citrea/-rpcpassword=$rpc_password/" docker-compose.yml
    sed -i "s/ROLLUP__DA__NODE_USERNAME=citrea/ROLLUP__DA__NODE_USERNAME=$rpc_user/" docker-compose.yml
    sed -i "s/ROLLUP__DA__NODE_PASSWORD=citrea/ROLLUP__DA__NODE_PASSWORD=$rpc_password/" docker-compose.yml
    sed -i "s/ROLLUP__RPC__BIND_PORT=8080/ROLLUP__RPC__BIND_PORT=$rpc_port/" docker-compose.yml
    sed -i "s/- \"8080:8080\"/- \"$rpc_port:$rpc_port\"/" docker-compose.yml
    
    docker-compose up -d
    echo "Custom installation completed!"
    cd $INITIAL_DIR
}

uninstall_node() {
    echo "Uninstalling Citrea node..."
    
    if [ ! -d "$BASE_DIR" ]; then
        echo "Directory citrea-node not found!"
        exit 1
    fi
    
    cd $BASE_DIR
    echo "Stopping and removing containers with volumes..."
    docker-compose down -v
    
    echo "Removing Docker images..."
    docker rmi bitcoin/bitcoin:28.0rc1 chainwayxyz/citrea-full-node:testnet
    
    cd $INITIAL_DIR
    echo "Removing citrea-node directory..."
    rm -rf $BASE_DIR
    
    echo "Citrea node has been successfully uninstalled!"
    echo "All containers, volumes, networks and images have been removed."
}

view_logs() {
    if [ ! -d "$BASE_DIR" ]; then
        echo "Node is not installed! Directory citrea-node not found."
        return
    fi
    
    cd $BASE_DIR && docker-compose logs
    cd $INITIAL_DIR
}

check_sync() {
    if [ ! -d "$BASE_DIR" ]; then
        echo "Node is not installed! Directory citrea-node not found."
        return
    fi
    
    echo "Checking sync status..."
    curl -X POST --header "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"citrea_syncStatus","params":[], "id":31}' \
        http://0.0.0.0:8080 | jq
}

show_menu() {
    echo -e "\nCitrea Node Manager"
    echo "1. Install node with default settings"
    echo "2. Install node with custom settings"
    echo "3. Uninstall node"
    echo "4. View logs"
    echo "5. Check sync status"
    echo "6. Exit"
}

while true; do
    show_menu
    read -p "Enter your choice (1-6): " choice
    
    case $choice in
        1) install_default ;;
        2) install_custom ;;
        3) uninstall_node ;;
        4) view_logs ;;
        5) check_sync ;;
        6)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done