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
# rm /etc/nginx/sites-available/default
# cp /deployment-artifacts-standalone-azure-linux-vm/default /etc/nginx/sites-available/default
# nginx -t
# nginx -s reload

# Set environment variables
export apiUrl=/api/v1
export ApiUrlShoppingCart=/api/v1
# export SqlConnectionString=
# export MongoConnectionString=

# Publish and start application
cd /tailwind/Source/Tailwind.Traders.Web
dotnet publish -c Release
# dotnet bin/Release/netcoreapp2.1/publish/Tailwind.Traders.Web.dll


# export SqlConnectionString='Server=tcp:twt-app-001.database.windows.net,1433;Initial Catalog=tailwind;User Id=twtadmin;Password=Password2020!;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;'