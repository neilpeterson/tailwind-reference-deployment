# https://www.hanselman.com/blog/PublishingAnASPNETCoreWebsiteToACheapLinuxVMHost.aspx

# Clone Anthony fork / update this once merged
git clone https://github.com/anthonychu/TailwindTraders-Website.git /tailwind
cd /tailwind
git checkout monolith

# Install dotenet 2.2
wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
add-apt-repository universe
apt-get install apt-transport-https
apt-get update
apt-get install dotnet-sdk-2.2=2.2.102-1 -y

# Install node / npn
apt install nodejs -y
apt install npm -y

# Install NGINX and config reverse proxy
git clone https://github.com/neilpeterson/tailwind-reference-deployment.git
apt-get install nginx -y
service nginx start
rm /etc/nginx/sites-available/default
curl https://raw.githubusercontent.com/neilpeterson/tailwind-reference-deployment/master/deployment-artifacts-standalone-azure-linux-vm/default > /etc/nginx/sites-available/default
nginx -t
nginx -s reload

echo "************"
echo $0
echo $1
echo "************"

# # Build SQL connection string
# SqlConnectionString="$(echo $1 | sed 's/{your_username}/twtadmin /g')"
# SqlConnectionString="$(echo $SqlConnectionString | sed 's/{your_password}/Password2020! /g')"

# # Set environment variables
# export apiUrl=/api/v1
# export ApiUrlShoppingCart=/api/v1
# export SqlConnectionString=$SqlConnectionString
# export MongoConnectionString=$2

# # Publish and start application
# cd /tailwind/Source/Tailwind.Traders.Web
# dotnet publish -c Release
# dotnet bin/Release/netcoreapp2.1/publish/Tailwind.Traders.Web.dll