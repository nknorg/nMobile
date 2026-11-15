package search

import (
	"crypto/ed25519"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/nknorg/nkn-sdk-go"
)

// NewSearchClient creates a new search client
// apiBase: API server address, e.g. "https://search.nkn.org/api/v1"
// For query-only usage, you can pass empty strings for privateKeyHex, publicKeyHex, and walletAddr
func NewSearchClient(apiBase string) (*SearchClient, error) {
	apiBaseURL, err := url.Parse(apiBase)
	if err != nil {
		return nil, fmt.Errorf("failed to parse API base URL: %w", err)
	}
	return &SearchClient{
		apiBase:    apiBaseURL,
		httpClient: &http.Client{Timeout: 30 * time.Second},
	}, nil
}

// NewSearchClientWithAuth creates a new search client with authentication
// apiBase: API server address, e.g. "https://search.nkn.org/api/v1"
// seed: NKN seed (hex format, 32 bytes = 64 characters)
func NewSearchClientWithAuth(apiBase string, seed []byte) (*SearchClient, error) {
	account, err := nkn.NewAccount(seed)
	if err != nil {
		return nil, fmt.Errorf("failed to create account: %w", err)
	}

	// Decode private key
	privateKeyBytes := account.PrivateKey
	if len(privateKeyBytes) != ed25519.PrivateKeySize {
		return nil, fmt.Errorf("private key must be %d bytes", ed25519.PrivateKeySize)
	}

	// Decode public key
	publicKeyBytes := account.PublicKey
	if len(publicKeyBytes) != ed25519.PublicKeySize {
		return nil, fmt.Errorf("public key must be %d bytes", ed25519.PublicKeySize)
	}

	apiBaseURL, err := url.Parse(apiBase)
	if err != nil {
		return nil, fmt.Errorf("failed to parse API base URL: %w", err)
	}

	return &SearchClient{
		apiBase:    apiBaseURL,
		privateKey: privateKeyBytes,
		publicKey:  publicKeyBytes,
		walletAddr: account.WalletAddress(),
		httpClient: &http.Client{Timeout: 30 * time.Second},
	}, nil
}

// Query queries data by keyword
// keyword: search keyword
// Returns JSON formatted query result string, error on failure
func (c *SearchClient) Query(keyword string) (string, error) {
	// Build query URL
	url := c.apiBase.JoinPath("data/query")
	q := url.Query()
	q.Set("q", keyword)
	url.RawQuery = q.Encode()

	// Create request
	req, err := http.NewRequest("GET", url.String(), nil)
	if err != nil {
		return "", err
	}

	// Send request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("query request failed: %w", err)
	}
	defer resp.Body.Close()

	// Read response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	// Return JSON string
	return string(body), nil
}

// QueryByID queries data by ID
// id: ID
// Returns JSON formatted query result string, error on failure
func (c *SearchClient) QueryByID(id string) (string, error) {
	// Build query URL
	url := c.apiBase.JoinPath("data/query")
	q := url.Query()
	q.Set("customId", id)
	url.RawQuery = q.Encode()

	// Create request
	req, err := http.NewRequest("GET", url.String(), nil)
	if err != nil {
		return "", err
	}

	// Send request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("query request failed: %w", err)
	}
	defer resp.Body.Close()

	// Read response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	// Return JSON string
	return string(body), nil
}

// GetMyInfo queries my own information by querying with nknAddress
// address: NKN address
// Returns JSON formatted query result string, error on failure
func (c *SearchClient) GetMyInfo(address string) (string, error) {
	// Build query URL
	url := c.apiBase.JoinPath("data/query")
	q := url.Query()
	q.Set("nknAddress", address)
	url.RawQuery = q.Encode()

	log.Printf("[GetMyInfo] Request URL: %s", url.String())

	// Create request
	req, err := http.NewRequest("GET", url.String(), nil)
	if err != nil {
		return "", err
	}

	// Send request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("query request failed: %w", err)
	}
	defer resp.Body.Close()

	log.Printf("[GetMyInfo] Response status: %d %s", resp.StatusCode, resp.Status)

	// Read response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	// Check HTTP status code
	if resp.StatusCode != http.StatusOK {
		log.Printf("[GetMyInfo] Error response body: %s", string(body))
		return "", fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(body))
	}

	log.Printf("[GetMyInfo] Response body: %s", string(body))

	// Return JSON string
	return string(body), nil
}

// SubmitUserData submits or updates user profile data to the search server
//
// Parameters:
//   - nknAddress: NKN client address (optional, format: "identifier.publickey" or just publickey)
//     If empty, defaults to publickey. Must be either "identifier.publickey" format or equal to publickey.
//   - customId: Custom identifier (optional, min 3 characters if provided, alphanumeric + underscore only)
//   - nickname: User nickname (optional, can be empty string)
//   - phoneNumber: Phone number (optional, can be empty string)
//
// # Returns nil on success, error on failure
//
// Important notes:
// - Each call performs fresh PoW (Proof of Work) automatically - you'll see timing logs
// - Server rate limit: 10 submits per minute
// - NO need to call Verify() first - SubmitUserData works independently
// - Verify() is only useful for query operations (gives 2-hour query access)
// - If publicKey already exists, will UPDATE the user data (can modify nickname, phoneNumber)
// - nknAddress validation: must be empty, equal to publickey, or in "identifier.publickey" format
//
// Example:
//
//	// Option 1: Use default (empty - will use publickey)
//	err := client.SubmitUserData("", "", "John Doe", "13800138000")
//
//	// Option 2: Use publickey directly
//	err := client.SubmitUserData(client.GetPublicKeyHex(), "", "John Doe", "13800138000")
//
//	// Option 3: Use custom identifier.publickey format
//	err := client.SubmitUserData(
//	    "alice." + client.GetPublicKeyHex(),  // nknAddress - identifier.publickey
//	    "myid123",                             // customId - optional
//	    "John Doe",                            // nickname - optional
//	    "13800138000",                         // phoneNumber - optional
//	)
func (c *SearchClient) SubmitUserData(nknAddress, customId, nickname, phoneNumber string) error {
	// Process nknAddress: if empty, use publicKey
	finalNknAddress := nknAddress
	publicKeyHex := c.GetPublicKeyHex()

	if finalNknAddress == "" {
		finalNknAddress = publicKeyHex
	} else {
		// Validate format if contains dot
		if strings.Contains(finalNknAddress, ".") {
			parts := strings.Split(finalNknAddress, ".")
			if len(parts) != 2 {
				return fmt.Errorf("invalid nknAddress format, expected: identifier.publickey")
			}
			providedPubKey := parts[1]
			if strings.ToLower(providedPubKey) != strings.ToLower(publicKeyHex) {
				return fmt.Errorf("nknAddress publickey suffix must match your actual publicKey")
			}
		} else {
			// If no dot, must equal publicKey
			if strings.ToLower(finalNknAddress) != strings.ToLower(publicKeyHex) {
				return fmt.Errorf("nknAddress must be either \"identifier.publickey\" format or equal to publicKey")
			}
		}
	}

	// Validate customId if provided
	if customId != "" && len(customId) < 3 {
		return fmt.Errorf("customId must be at least 3 characters if provided")
	}

	submitResp, err := c.submitData(finalNknAddress, customId, nickname, phoneNumber)
	if err != nil {
		return fmt.Errorf("failed to submit user data: %w", err)
	}

	if !submitResp.Success {
		return fmt.Errorf("submit failed: %s", submitResp.Error)
	}

	return nil
}

// Verify verifies the public key (completes PoW challenge)
// Returns nil on success, error on failure
func (c *SearchClient) Verify() error {
	// 1. Get challenge
	challenge, err := c.getChallenge()
	if err != nil {
		return fmt.Errorf("failed to get challenge: %w", err)
	}

	// 2. Solve challenges
	solutions, err := c.solveChallenges(challenge)
	if err != nil {
		return fmt.Errorf("failed to solve challenges: %w", err)
	}

	// 3. Submit verification
	verifyResp, err := c.verify(solutions)
	if err != nil {
		return fmt.Errorf("failed to verify: %w", err)
	}

	if !verifyResp.Success {
		return fmt.Errorf("verification failed: %s", verifyResp.Error)
	}

	// 4. Update status
	c.mu.Lock()
	c.isVerified = true
	c.verifiedUntil = time.Now().Add(2 * time.Hour) // Valid for 2 hours
	c.mu.Unlock()

	return nil
}
