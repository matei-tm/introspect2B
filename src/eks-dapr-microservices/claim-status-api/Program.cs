using Amazon.DynamoDBv2;
using Amazon.S3;
using Amazon.BedrockRuntime;
using ClaimStatusApi.Services;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

// Configure Serilog
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .WriteTo.Console()
    .CreateLogger();

builder.Host.UseSerilog();

// Add AWS services
builder.Services.AddAWSService<IAmazonDynamoDB>();
builder.Services.AddAWSService<IAmazonS3>();
builder.Services.AddScoped<AmazonBedrockRuntimeClient>();

// Add custom services
builder.Services.AddScoped<IDynamoDbService, DynamoDbService>();
builder.Services.AddScoped<IS3Service, S3Service>();
builder.Services.AddScoped<IBedrockService, BedrockService>();

// Add controllers
builder.Services.AddControllers();

// Add API documentation
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new Microsoft.OpenApi.Models.OpenApiInfo
    {
        Title = "Claim Status API",
        Version = "v1",
        Description = "GenAI-enabled Claim Status API with Amazon Bedrock integration",
        Contact = new Microsoft.OpenApi.Models.OpenApiContact
        {
            Name = "Insurance Team",
            Url = new Uri("https://example.com")
        }
    });
});

// Add health checks
builder.Services.AddHealthChecks();

// Add CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", builder =>
    {
        builder.AllowAnyOrigin()
               .AllowAnyMethod()
               .AllowAnyHeader();
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("AllowAll");
app.MapHealthChecks("/health");
app.MapControllers();

try
{
    Log.Information("Starting Claim Status API");
    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
