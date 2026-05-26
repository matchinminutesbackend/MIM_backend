// Cascading location picker data for the signup form.
//
// Goal: let users pick country → state → city instead of typing free-form,
// which keeps the city field consistent across profiles (good for matching
// and filtering). India is the default market, so it gets the full state +
// city breakdown. Other countries fall back to free-text state + city
// because maintaining a global city DB client-side is not worth the KB.
//
// Only the `city` value ends up in the backend — `state` is used purely
// to narrow the city dropdown. If we later add a `state` column to the
// profile table, plumb it through profile/schemas.py first.

// Countries ordered with India first (default), then English-speaking
// markets, then the rest alphabetical. Feel free to add more as the app
// expands — anything not in this list can still be typed via "Other".
export const COUNTRIES = [
  "India",
  "United States",
  "United Kingdom",
  "Canada",
  "Australia",
  "New Zealand",
  "Singapore",
  "United Arab Emirates",
  "Saudi Arabia",
  "Qatar",
  "Malaysia",
  "Germany",
  "France",
  "Italy",
  "Spain",
  "Netherlands",
  "Ireland",
  "Sweden",
  "Norway",
  "Denmark",
  "Switzerland",
  "Japan",
  "South Korea",
  "China",
  "Hong Kong",
  "Bangladesh",
  "Pakistan",
  "Nepal",
  "Sri Lanka",
  "South Africa",
  "Nigeria",
  "Kenya",
  "Egypt",
  "Brazil",
  "Mexico",
  "Argentina",
  "Other",
];

// Indian states + UTs, each mapped to a list of notable cities.
// Cities are ordered roughly by population / familiarity so the most-
// picked ones surface first in the dropdown.
export const INDIA_STATES = {
  "Andhra Pradesh": [
    "Visakhapatnam", "Vijayawada", "Guntur", "Nellore", "Kurnool",
    "Tirupati", "Kakinada", "Rajahmundry", "Anantapur", "Kadapa",
  ],
  "Arunachal Pradesh": [
    "Itanagar", "Naharlagun", "Pasighat", "Tawang", "Ziro",
  ],
  "Assam": [
    "Guwahati", "Silchar", "Dibrugarh", "Jorhat", "Nagaon",
    "Tinsukia", "Tezpur", "Bongaigaon",
  ],
  "Bihar": [
    "Patna", "Gaya", "Bhagalpur", "Muzaffarpur", "Purnia",
    "Darbhanga", "Bihar Sharif", "Arrah", "Begusarai",
  ],
  "Chhattisgarh": [
    "Raipur", "Bhilai", "Bilaspur", "Korba", "Durg", "Rajnandgaon",
  ],
  "Goa": [
    "Panaji", "Margao", "Vasco da Gama", "Mapusa", "Ponda", "Calangute",
  ],
  "Gujarat": [
    "Ahmedabad", "Surat", "Vadodara", "Rajkot", "Gandhinagar",
    "Bhavnagar", "Jamnagar", "Junagadh", "Gandhidham", "Anand",
  ],
  "Haryana": [
    "Gurgaon", "Faridabad", "Panipat", "Hisar", "Rohtak",
    "Karnal", "Ambala", "Sonipat", "Yamunanagar", "Panchkula",
  ],
  "Himachal Pradesh": [
    "Shimla", "Dharamshala", "Manali", "Kullu", "Mandi",
    "Solan", "Hamirpur", "Bilaspur",
  ],
  "Jharkhand": [
    "Ranchi", "Jamshedpur", "Dhanbad", "Bokaro", "Hazaribagh", "Deoghar",
  ],
  "Karnataka": [
    "Bangalore", "Mysore", "Hubli", "Mangalore", "Belgaum",
    "Gulbarga", "Davangere", "Bellary", "Tumkur", "Shimoga", "Udupi",
  ],
  "Kerala": [
    "Kochi", "Thiruvananthapuram", "Kozhikode", "Thrissur", "Kollam",
    "Kannur", "Alappuzha", "Palakkad", "Malappuram", "Kottayam",
  ],
  "Madhya Pradesh": [
    "Bhopal", "Indore", "Jabalpur", "Gwalior", "Ujjain",
    "Sagar", "Dewas", "Satna", "Ratlam", "Rewa",
  ],
  "Maharashtra": [
    "Mumbai", "Pune", "Nagpur", "Nashik", "Aurangabad",
    "Thane", "Navi Mumbai", "Solapur", "Kolhapur", "Amravati",
    "Sangli", "Jalgaon", "Akola", "Nanded",
  ],
  "Manipur": [
    "Imphal", "Thoubal", "Bishnupur", "Churachandpur",
  ],
  "Meghalaya": [
    "Shillong", "Tura", "Jowai", "Nongstoin",
  ],
  "Mizoram": [
    "Aizawl", "Lunglei", "Champhai",
  ],
  "Nagaland": [
    "Kohima", "Dimapur", "Mokokchung", "Tuensang",
  ],
  "Odisha": [
    "Bhubaneswar", "Cuttack", "Rourkela", "Berhampur", "Sambalpur",
    "Puri", "Balasore",
  ],
  "Punjab": [
    "Ludhiana", "Amritsar", "Jalandhar", "Patiala", "Bathinda",
    "Mohali", "Pathankot", "Hoshiarpur",
  ],
  "Rajasthan": [
    "Jaipur", "Jodhpur", "Udaipur", "Kota", "Ajmer",
    "Bikaner", "Bharatpur", "Alwar", "Sikar",
  ],
  "Sikkim": [
    "Gangtok", "Namchi", "Gyalshing", "Mangan",
  ],
  "Tamil Nadu": [
    "Chennai", "Coimbatore", "Madurai", "Tiruchirappalli", "Salem",
    "Tirunelveli", "Erode", "Vellore", "Thoothukudi", "Dindigul",
    "Thanjavur", "Tiruppur",
  ],
  "Telangana": [
    "Hyderabad", "Warangal", "Nizamabad", "Karimnagar", "Khammam",
    "Ramagundam", "Secunderabad",
  ],
  "Tripura": [
    "Agartala", "Udaipur", "Dharmanagar", "Kailashahar",
  ],
  "Uttar Pradesh": [
    "Lucknow", "Kanpur", "Ghaziabad", "Agra", "Noida",
    "Varanasi", "Meerut", "Allahabad", "Bareilly", "Aligarh",
    "Moradabad", "Saharanpur", "Gorakhpur", "Faizabad", "Jhansi",
    "Mathura", "Firozabad", "Muzaffarnagar",
  ],
  "Uttarakhand": [
    "Dehradun", "Haridwar", "Roorkee", "Haldwani", "Rishikesh",
    "Nainital", "Mussoorie",
  ],
  "West Bengal": [
    "Kolkata", "Howrah", "Durgapur", "Asansol", "Siliguri",
    "Darjeeling", "Bardhaman", "Malda", "Kharagpur",
  ],
  // Union Territories
  "Andaman and Nicobar Islands": [
    "Port Blair",
  ],
  "Chandigarh": [
    "Chandigarh",
  ],
  "Dadra and Nagar Haveli and Daman and Diu": [
    "Daman", "Silvassa", "Diu",
  ],
  "Delhi": [
    "New Delhi", "Delhi", "Dwarka", "Rohini", "Pitampura",
    "Karol Bagh", "Saket", "Vasant Kunj",
  ],
  "Jammu and Kashmir": [
    "Srinagar", "Jammu", "Anantnag", "Baramulla", "Udhampur",
  ],
  "Ladakh": [
    "Leh", "Kargil",
  ],
  "Lakshadweep": [
    "Kavaratti",
  ],
  "Puducherry": [
    "Puducherry", "Karaikal", "Yanam", "Mahe",
  ],
};

export const INDIA_STATE_NAMES = Object.keys(INDIA_STATES).sort();
