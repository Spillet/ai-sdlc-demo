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

app.MapPost("/claims/remaining-days", (RemainingDaysRequest request) =>
{
    try
    {
        var remaining = ClaimPolicy.RemainingDays(request.ReceivedOn, request.Today);
        var expired = remaining < 0;
        return Results.Ok(new RemainingDaysResponse(
            expired ? 0 : remaining,
            ClaimPolicy.ResolutionDeadline(request.ReceivedOn),
            expired,
            expired ? -remaining : 0,
            expired
                ? $"Lhůta na vyřízení reklamace uplynula před {-remaining} dny."
                : $"Do konce lhůty na vyřízení reklamace zbývá dní: {remaining}."));
    }
    catch (ArgumentException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapPost("/claims/refund", (RefundRequest request) =>
    Results.Ok(new { amount = RefundCalculator.Calculate(request.Price, request.Outcome, request.PartialRate) }));

app.Run();

public record ClaimRequest(DateOnly PurchasedOn, DateOnly ClaimedOn);

public record ClaimEvaluation(bool WithinWarranty, DateOnly? ResolveBy);

public record RemainingDaysRequest(DateOnly ReceivedOn, DateOnly Today);

public record RemainingDaysResponse(int RemainingDays, DateOnly ResolveBy, bool Expired, int DaysOverdue, string Message);

public record RefundRequest(decimal Price, ClaimOutcome Outcome, decimal PartialRate = 0m);
