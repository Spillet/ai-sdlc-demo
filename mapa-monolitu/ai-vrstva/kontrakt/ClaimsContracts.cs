// [MODEL] Návrh kontraktu služby Reklamace (.NET). Nekompilováno, neimplementováno.
// Vzniklo z dokumentace tří procedur. Tvar API a událostí je k diskusi s týmem
// reklamací, skladu a plateb; místa označená [OVĚŘÍ ČLOVĚK] jsou rozhodnutí, ne fakta.

namespace Kompas.Claims.Contracts;

// ---------------------------------------------------------------------------
// GET /claims/{claimId}            náhrada usp_Claim_GetDetail (čtecí cesta, pilot)
//   200 ClaimDetail | 403 (dnes RETURN 5 bez result setů) | 404
// ---------------------------------------------------------------------------
public sealed record ClaimDetail(
    int ClaimId,
    string ClaimNumber,
    string ReasonCode,                 // dnes sloupec ClaimType, obsahuje kód důvodu
    ClaimStatus Status,
    ClaimResolution? Resolution,
    DateOnly HandlingDeadline,         // Claim.DeadlineAt = 30 dní na vyřízení
    int DaysLeft,                      // počítá služba, ne DB
    OrderRef Order,                    // data z domény Objednávky [OVĚŘÍ ČLOVĚK] API, nebo čtecí kopie?
    CustomerRef Customer,              // data z domény Zákazníci
    ServiceCenterRef? ServiceCenter,
    IReadOnlyList<ClaimItemDto> Items,
    IReadOnlyList<StatusChangeDto> History,
    IReadOnlyList<ClaimDocumentDto> Documents);

public sealed record OrderRef(int OrderId, string OrderNumber, DateTimeOffset OrderedAt);
public sealed record CustomerRef(int CustomerId, string Name, string Email, bool IsBusiness);
public sealed record ServiceCenterRef(string Name, string City);
public sealed record ClaimItemDto(int ClaimItemId, int OrderItemId, string ProductCode, string ProductName,
                                  int Qty, decimal UnitPrice, string DefectDescription);
public sealed record StatusChangeDto(ClaimStatus From, ClaimStatus To, string? Note, DateTimeOffset At, string? ChangedBy);
public sealed record ClaimDocumentDto(int ClaimDocumentId, string FileName, string StorageKey);

// ---------------------------------------------------------------------------
// POST /claims                     náhrada usp_Claim_Create
//   201 + Location | 400 ProblemDetails podle kódu
// ---------------------------------------------------------------------------
public sealed record CreateClaimRequest(int OrderItemId, int Qty, string ReasonCode, string DefectText);
public sealed record CreateClaimResponse(int ClaimId, string ClaimNumber);

public static class CreateClaimErrors
{
    // mapování návratových kódů procedury na typy ProblemDetails
    public const string OrderItemNotFound   = "claims/order-item-not-found";   // RETURN 1
    public const string UnknownReason       = "claims/unknown-reason";         // RETURN 2
    public const string WarrantyExpired     = "claims/warranty-expired";       // RETURN 3
    public const string QtyExceedsOrdered   = "claims/qty-exceeds-ordered";    // RETURN 4
    public const string InvalidQty          = "claims/invalid-qty";            // dnes neexistuje: Qty <= 0 projde
}
// [OVĚŘÍ ČLOVĚK] Zákonná lhůta: od převzetí, nebo od objednávky (dnešní chování)?
// [MODEL] Kontrolu množství dělat v transakci se zámkem na položku (dnes souběh).

// ---------------------------------------------------------------------------
// POST /claims/{claimId}/status    náhrada usp_Claim_SetStatus
//   204 | 404 (RETURN 1) | 409 uzavřená reklamace (RETURN 2) | 409 nepovolený přechod
// ---------------------------------------------------------------------------
public sealed record ChangeClaimStatusRequest(ClaimStatus NewStatus, string? Note);

public enum ClaimStatus : byte
{
    New = 1, InService = 2, AcceptedRepair = 3, AcceptedReplace = 4, AcceptedRefund = 5,
    DeadlineAtRisk = 7,                // nastavuje jen noční job usp_Claim_OverdueCheck
    Rejected = 9
}
public enum ClaimResolution { Repair, Replace, Refund, Rejected }

// Místo přímého UPDATE dbo.StockLevel a EXEC usp_Refund_Create vydá služba událost
// přes outbox (ve stejné transakci jako změna stavu). Vlastníci dat ji zpracují sami.
public sealed record ClaimResolved(
    Guid EventId, int ClaimId, int OrderId, ClaimResolution Resolution,
    IReadOnlyList<ResolvedItem> Items, DateTimeOffset At);
public sealed record ResolvedItem(int OrderItemId, int ProductId, int Qty, decimal UnitPrice);
// Konzumenti:
//   Sklad   – Replace: odpis/rezervace ve správném skladu (dnes natvrdo sklad 1)
//   Platby  – Refund: refundace podle pravidel plateb (dnes Qty × UnitPrice, bez slev)
// [OVĚŘÍ ČLOVĚK] Je asynchronní odpis a refundace přijatelná?

public interface IClaimsService
{
    Task<ClaimDetail?> GetAsync(int claimId, CancellationToken ct);
    Task<CreateClaimResponse> CreateAsync(CreateClaimRequest request, int userId, CancellationToken ct);
    Task ChangeStatusAsync(int claimId, ChangeClaimStatusRequest request, int userId, CancellationToken ct);
}
