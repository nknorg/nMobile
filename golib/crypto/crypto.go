package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"github.com/nknorg/nkn/v2/crypto/ed25519"
)

func GCMEncrypt(plaintext []byte, key []byte, nonceSize int) ([]byte, error) {
	c, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(c)
	if err != nil {
		return nil, err
	}

	nonce := make([]byte, nonceSize)
	_, err = rand.Read(nonce)
	if err != nil {
		return nil, err
	}

	ciphertext := gcm.Seal(nonce, nonce, plaintext, nil)
	return ciphertext, nil
}

func GCMDecrypt(ciphertext []byte, key []byte, nonceSize int) ([]byte, error) {
	c, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(c)
	if err != nil {
		return nil, err
	}

	if len(ciphertext) < nonceSize {
		return nil, err
	}

	nonce, ciphertext := ciphertext[:nonceSize], ciphertext[nonceSize:]
	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	return plaintext, err
}

func GetPublicKeyFromPrivateKey(privateKey []byte) []byte {
	return ed25519.GetPublicKeyFromPrivateKey(privateKey)
}

func GetPrivateKeyFromSeed(seed []byte) []byte {
	return ed25519.GetPrivateKeyFromSeed(seed)
}

func GetSeedFromPrivateKey(priKey []byte) []byte {
	return ed25519.GetSeedFromPrivateKey(priKey)
}

func Sign(privateKey, data []byte) ([]byte, error) {
	return ed25519.Sign(privateKey, data)
}

func Verify(publicKey, data, signature []byte) error {
	return ed25519.Verify(publicKey, data, signature)
}
