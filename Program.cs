using Npgsql;

var builder = WebApplication.CreateBuilder(args);

var app = builder.Build();

app.MapGet("/", async () =>
{
    var dbHost = Environment.GetEnvironmentVariable("DB_HOST");
    var dbName = Environment.GetEnvironmentVariable("DB_NAME");
    var dbUser = Environment.GetEnvironmentVariable("DB_USER");
    var dbPassword = Environment.GetEnvironmentVariable("DB_PASSWORD");

    string databaseStatus;

    if (string.IsNullOrWhiteSpace(dbHost) ||
        string.IsNullOrWhiteSpace(dbName) ||
        string.IsNullOrWhiteSpace(dbUser) ||
        string.IsNullOrWhiteSpace(dbPassword))
    {
        databaseStatus = "Not configured";
    }
    else
    {
        try
        {
            var connectionString =
                $"Host={dbHost};" +
                $"Port=6432;" +
                $"Database={dbName};" +
                $"Username={dbUser};" +
                $"Password={dbPassword};" +
                $"SSL Mode=Require;";

            await using var connection = new NpgsqlConnection(connectionString);
            await connection.OpenAsync();

            await using var command = new NpgsqlCommand("SELECT 1", connection);
            await command.ExecuteScalarAsync();

            databaseStatus = "Connected";
        }
        catch (Exception)
        {
            databaseStatus = "Connection failed";
        }
    }

    var databaseClass =
        databaseStatus == "Connected"
            ? "ok"
            : "warning";

    var html = $$"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>Programming Exam</title>

            <style>
                body {
                    font-family: Arial, sans-serif;
                    background: #f4f4f4;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                }

                .card {
                    background: white;
                    padding: 40px;
                    border-radius: 15px;
                    box-shadow: 0 4px 15px rgba(0,0,0,0.15);
                    text-align: center;
                    min-width: 350px;
                }

                h1 {
                    margin-bottom: 20px;
                }

                .ok {
                    color: green;
                    font-weight: bold;
                }

                .warning {
                    color: darkorange;
                    font-weight: bold;
                }
            </style>
        </head>

        <body>
            <div class="card">

                <h1>Programming Exam</h1>

                <p>ASP.NET Core application</p>

                <p>
                    Application status:
                    <span class="ok">Running</span>
                </p>

                <p>
                    Database status:
                    <span class="{{databaseClass}}">
                        {{databaseStatus}}
                    </span>
                </p>

                <p>
                    Student: Igor Avramenko
                </p>

            </div>
        </body>
        </html>
        """;

    return Results.Content(html, "text/html");
});

app.MapGet("/health", () =>
{
    return Results.Ok(new
    {
        status = "healthy",
        time = DateTime.UtcNow
    });
});

app.Run();