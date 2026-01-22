FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy project file
COPY ["claim-status-api.csproj", "./"]

# Restore dependencies
RUN dotnet restore "claim-status-api.csproj"

# Copy source code
COPY . .

# Build
RUN dotnet build "claim-status-api.csproj" -c Release -o /app/build

# Publish
FROM build AS publish
RUN dotnet publish "claim-status-api.csproj" -c Release -o /app/publish

# Runtime image
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY --from=publish /app/publish .

# Create non-root user
RUN useradd -m -u 1000 dotnet && chown -R dotnet:dotnet /app
USER dotnet

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

ENTRYPOINT ["dotnet", "ClaimStatusApi.dll"]
