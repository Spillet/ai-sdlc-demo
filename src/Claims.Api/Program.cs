using Claims.Api.Domain;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

app.MapPost("/claims/evaluate", (ClaimRequest request) =>
{
    var withinWarranty = ClaimPolicy.IsWithinWarranty(request.PurchasedOn, request.ClaimedOn);
    return Results.Ok(new ClaimEvaluation(
        withinWarranty,
        withinWarranty ? ClaimPolicy.ResolutionDeadline(request.ClaimedOn) : null));
});

app.Run();

public record ClaimRequest(DateOnly PurchasedOn, DateOnly ClaimedOn);

public record ClaimEvaluation(bool WithinWarranty, DateOnly? ResolveBy);
