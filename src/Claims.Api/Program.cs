using Claims.Api.Content;
using Claims.Api.Domain;
using Claims.Api.Refunds;

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

app.MapPost("/claims/refund", (RefundRequest request) =>
    Results.Ok(new { amount = RefundCalculator.Calculate(request.Price, request.Outcome, request.PartialRate) }));

app.MapMessageEndpoints();

app.Run();

public record ClaimRequest(DateOnly PurchasedOn, DateOnly ClaimedOn);

public record ClaimEvaluation(bool WithinWarranty, DateOnly? ResolveBy);

public record RefundRequest(decimal Price, ClaimOutcome Outcome, decimal PartialRate = 0m);
