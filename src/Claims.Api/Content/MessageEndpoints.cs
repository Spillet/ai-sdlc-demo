using Microsoft.AspNetCore.Http.HttpResults;

namespace Claims.Api.Content;

/// <summary>Endpointy pro texty zpráv. Handlery jsou veřejné metody, aby šly testovat bez HTTP serveru.</summary>
public static class MessageEndpoints
{
    public static void MapMessageEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/claims/messages", ListKeys);
        app.MapGet("/claims/messages/{key}", GetMessage);
    }

    public static Ok<string[]> ListKeys() =>
        TypedResults.Ok(MessageCatalog.All.Select(t => t.Key).ToArray());

    public static Results<Ok<RenderedMessage>, NotFound> GetMessage(
        string key, string? orderNumber, string? claimNumber, string? resolveBy)
    {
        var template = MessageCatalog.Find(key);
        if (template is null)
        {
            return TypedResults.NotFound();
        }
        return TypedResults.Ok(MessageCatalog.Render(template, new Dictionary<string, string>
        {
            ["orderNumber"] = orderNumber ?? "",
            ["claimNumber"] = claimNumber ?? "",
            ["resolveBy"] = resolveBy ?? "",
        }));
    }
}
