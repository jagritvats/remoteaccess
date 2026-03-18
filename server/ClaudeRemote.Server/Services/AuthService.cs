using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using ClaudeRemote.Server.Models;
using Microsoft.IdentityModel.Tokens;

namespace ClaudeRemote.Server.Services;

public class AuthService
{
    private readonly string _pin;
    private readonly string _jwtSecret;
    private readonly List<PairedDevice> _pairedDevices = [];
    private readonly TimeSpan _tokenExpiry = TimeSpan.FromDays(7);

    public string Pin => _pin;

    public AuthService()
    {
        _pin = Random.Shared.Next(100000, 999999).ToString();
        _jwtSecret = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));
    }

    public PairResponse? TryPair(PairRequest request)
    {
        if (request.Pin != _pin)
            return null;

        var tokenId = Guid.NewGuid().ToString("N")[..8];
        var expiresAt = DateTime.UtcNow.Add(_tokenExpiry);

        var tokenHandler = new JwtSecurityTokenHandler();
        var key = Encoding.UTF8.GetBytes(_jwtSecret);
        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(
            [
                new Claim("device", request.DeviceName),
                new Claim("tid", tokenId)
            ]),
            Expires = expiresAt,
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(key),
                SecurityAlgorithms.HmacSha256Signature)
        };

        var token = tokenHandler.CreateToken(tokenDescriptor);
        var tokenString = tokenHandler.WriteToken(token);

        _pairedDevices.Add(new PairedDevice
        {
            DeviceName = request.DeviceName,
            TokenId = tokenId,
            ExpiresAt = expiresAt
        });

        return new PairResponse
        {
            Token = tokenString,
            ServerName = Environment.MachineName,
            ExpiresAt = new DateTimeOffset(expiresAt).ToUnixTimeMilliseconds()
        };
    }

    public TokenValidationParameters GetTokenValidationParameters() => new()
    {
        ValidateIssuer = false,
        ValidateAudience = false,
        ValidateLifetime = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwtSecret)),
        ClockSkew = TimeSpan.FromMinutes(1)
    };

    public IReadOnlyList<PairedDevice> GetPairedDevices() => _pairedDevices.AsReadOnly();

    public void RegeneratePin() { } // PIN stays constant for session lifetime
}

file class RandomNumberGenerator
{
    public static byte[] GetBytes(int count)
    {
        var bytes = new byte[count];
        System.Security.Cryptography.RandomNumberGenerator.Fill(bytes);
        return bytes;
    }
}
