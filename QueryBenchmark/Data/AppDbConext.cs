using Microsoft.EntityFrameworkCore;
using QueryBenchmark.Models;

namespace QueryBenchmark.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<ExecutionLog> ExecutionLogs { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<ExecutionLog>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.QueryName).HasMaxLength(200);
            entity.Property(e => e.QueryDescription).HasMaxLength(500);
            entity.Property(e => e.ErrorMessage).HasMaxLength(2000);
            entity.Property(e => e.ExecutedBy).HasMaxLength(100);
        });
    }
}