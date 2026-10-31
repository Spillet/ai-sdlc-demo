using Claims.Api.Content;
using Microsoft.AspNetCore.Http.HttpResults;

namespace Claims.Tests.Content;

public class MessageCatalogTests
{
    private static readonly Dictionary<string, string> Values = new()
    {
        ["orderNumber"] = "2026-1001",
        ["claimNumber"] = "R-17",
        ["resolveBy"] = "30. 11. 2026",
    };

    [Fact]
    public void Every_template_has_key_subject_and_body()
    {
        var templates = MessageCatalog.All.ToList();

        Assert.NotEmpty(templates);
        Assert.All(templates, t =>
        {
            Assert.False(string.IsNullOrWhiteSpace(t.Key));
            Assert.False(string.IsNullOrWhiteSpace(t.Subject));
            Assert.False(string.IsNullOrWhiteSpace(t.Body));
        });
    }

    [Fact]
    public void Templates_use_only_known_placeholders()
    {
        foreach (var template in MessageCatalog.All)
        {
            var message = MessageCatalog.Render(template, Values);

            Assert.DoesNotContain("{", message.Subject + message.Body);
            Assert.DoesNotContain("}", message.Subject + message.Body);
        }
    }

    [Fact]
    public void Render_fills_placeholders()
    {
        var template = MessageCatalog.Find("claim-received");
        Assert.NotNull(template);

        var message = MessageCatalog.Render(template, Values);

        Assert.Equal("Reklamaci R-17 jsme přijali", message.Subject);
        Assert.Contains("2026-1001", message.Body);
        Assert.Contains("30. 11. 2026", message.Body);
    }

    [Fact]
    public void Endpoint_returns_rendered_message()
    {
        var result = MessageEndpoints.GetMessage("claim-received", "2026-1001", "R-17", "30. 11. 2026");

        var ok = Assert.IsType<Ok<RenderedMessage>>(result.Result);
        Assert.NotNull(ok.Value);
        Assert.Contains("R-17", ok.Value.Subject);
    }

    [Fact]
    public void Endpoint_returns_not_found_for_unknown_key()
    {
        var result = MessageEndpoints.GetMessage("neexistuje", null, null, null);

        Assert.IsType<NotFound>(result.Result);
    }

    [Fact]
    public void List_returns_all_keys()
    {
        var keys = MessageEndpoints.ListKeys().Value;

        Assert.NotNull(keys);
        Assert.Contains("claim-received", keys);
        Assert.Contains("claim-resolved", keys);
    }
}
