"""Deterministic RSA key pair + JWKS document for OIDC verifier tests."""

import json
from datetime import datetime

import jwt
from cryptography.hazmat.primitives.asymmetric import rsa
from jwt.algorithms import RSAAlgorithm

from tests.conftest import TEST_AUDIENCE, TEST_ISSUER

KID = "test-key-1"
_PRIVATE = rsa.generate_private_key(public_exponent=65537, key_size=2048)
_PUBLIC_JWK = json.loads(RSAAlgorithm.to_jwk(_PRIVATE.public_key()))
_PUBLIC_JWK.update({"kid": KID, "alg": "RS256", "use": "sig"})
JWKS: dict[str, object] = {"keys": [_PUBLIC_JWK]}


def rs256_token(
    *,
    subject: str,
    now: datetime,
    ttl_seconds: int = 300,
    kid: str = KID,
    issuer: str = TEST_ISSUER,
) -> str:
    """Mint an RS256 token signed with the fixture private key."""
    claims = {
        "sub": subject,
        "iss": issuer,
        "aud": TEST_AUDIENCE,
        "iat": int(now.timestamp()),
        "exp": int(now.timestamp()) + ttl_seconds,
    }
    return jwt.encode(claims, _PRIVATE, algorithm="RS256", headers={"kid": kid})


__all__ = ["JWKS", "KID", "rs256_token"]
