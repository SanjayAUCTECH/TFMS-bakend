using Microsoft.Data.SqlClient;

namespace TFMS_software_api.Repositories;

/// <summary>Factory for creating SQL connections — injected into all repositories.</summary>
public interface IDbConnectionFactory
{
    SqlConnection CreateConnection();
}

public sealed class SqlConnectionFactory : IDbConnectionFactory
{
    private readonly string _connectionString;
    public SqlConnectionFactory(string connectionString) => _connectionString = connectionString;

    public SqlConnection CreateConnection() => new(_connectionString);
}
