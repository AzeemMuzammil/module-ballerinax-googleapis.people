// Copyright (c) 2021 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;

# Ballerina Google People API connector provides the capability to access Google People API.
# This connector lets you to read and manage the authenticated user's contacts and contact groups.
#
# + googleContactClient - Connector HTTP endpoint
@display {label: "Google People API", iconPath: "icon.png"}
public isolated client class Client {
    final http:Client googleContactClient;

    # Initializes the connector. During initialization you can pass either http:BearerTokenConfig
    # if you have a bearer token or http:OAuth2RefreshTokenGrantConfig if you have Oauth tokens.
    # Create a [Google account](https://accounts.google.com/signup/v2/webcreateaccount?utm_source=ga-ob-search&utm_medium=google-account&flowName=GlifWebSignIn&flowEntry=SignUp) and 
    # obtain tokens following [this guide](https://developers.google.com/identity/protocols/oauth2). 
    # Configure the OAuth2 tokens to have the [required permissions](https://developers.google.com/sheets/api/guides/authorizing).
    #
    # + config - Configuration for the connector
    # + return - `http:Error` in case of failure to initialize or `null` if successfully initialized
    public isolated function init(ConnectionConfig config) returns error? {
        http:ClientConfiguration httpClientConfig = {
            auth: config.auth,
            httpVersion: config.httpVersion,
            http1Settings: {...config.http1Settings},
            http2Settings: config.http2Settings,
            timeout: config.timeout,
            forwarded: config.forwarded,
            poolConfig: config.poolConfig,
            cache: config.cache,
            compression: config.compression,
            circuitBreaker: config.circuitBreaker,
            retryConfig: config.retryConfig,
            responseLimits: config.responseLimits,
            secureSocket: config.secureSocket,
            proxy: config.proxy,
            validation: config.validation
        };
        self.googleContactClient = check new (BASE_URL, httpClientConfig);
    }

    # Fetch all from "Other Contacts".
    # 
    # + readMasks - Restrict which fields on the person are returned
    # + options - Record that contains options
    # + return - Stream of `PersonResponse` will have information specified by `Read Masks` on success else an `error`
    @display {label: "List OtherContacts"}
    isolated remote function listOtherContacts(@display {label: "Read Masks"} OtherContactFieldMask[] readMasks, 
                                               @display {label: "List Options"} ContactListOptions? options = ()) 
                                               returns @display {label: "Stream of PersonResponse"} 
                                               stream<PersonResponse>|error {
        string path = LIST_OTHERCONTACT_PATH;
        string pathWithReadMasks = prepareUrlWithReadMasks(path, readMasks);
        PersonResponse[] persons = [];
        return getOtherContactsStream(self.googleContactClient, persons, pathWithReadMasks, options);
    }

    # Create a contact.
    # 
    # + person - Record of type of `CreatePerson`
    # + personFields - Restrict which fields on the person are returned
    # + return - `PersonResponse` will have information specified by `Person Fields` on success else an `error`
    @display {label: "Create Contact"}
    isolated remote function createContact(@display {label: "Contact Details"} Person person, 
                                           @display {label: "Person Fields"} FieldMask[] personFields) returns 
                                           @display {label: "PersonResponse"} PersonResponse|error {
        string path = CREATE_CONTACT_PATH + QUESTION_MARK;
        json payload = check person.cloneWithType(json);
        http:Request request = new;
        string pathWithPersonFields = prepareUrlWithPersonFields(path, personFields);
        request.setJsonPayload(payload);
        http:Response httpResponse = check self.googleContactClient->post(pathWithPersonFields, request);
        var response = check handleResponse(httpResponse);
        return check response.cloneWithType(PersonResponse);
    }

    # Fetch a contact.
    # 
    # + resourceName - Contact resource name
    # + personFields - Restrict which fields on the person are returned
    # + return - `PersonResponse` will have information specified by `Person Fields` on success else an `error`
    @display {label: "Get Contact"}
    isolated remote function getContact(@display {label: "Resource Name"} string resourceName, 
                                        @display {label: "Person Fields"} FieldMask[] personFields) returns 
                                        @display {label: "PersonResponse"} PersonResponse|error {
        string path = SLASH + resourceName + QUESTION_MARK;
        string pathWithPersonFields = prepareUrlWithPersonFields(path, personFields);
        http:Response httpResponse = check self.googleContactClient->get(pathWithPersonFields);
        var response = check handleResponse(httpResponse);
        return check response.cloneWithType(PersonResponse);
    }

    # Search a contacts.
    # 
    # + query - String to be searched
    # + readMasks - Restrict which fields on the person are returned
    # + return - `PersonResponse[]` will have information specified by `Person Fields` on success else an `error`
    @display {label: "Search Contact"}
    isolated remote function searchContacts(@display {label: "Searchable Substring"} string query,
                                            @display {label: "Read Masks"} FieldMask[] readMasks) returns 
                                            @display {label: "PersonResponses Array"} PersonResponse[]|error {
        string path = SLASH + SEARCH_CONTACT_PATH + QUESTION_MARK;
        string pathWithReadMasks = prepareUrlWithReadMasks(path, readMasks);
        string pathWithQuery = pathWithReadMasks + QUERY_PATH + query;
        http:Response httpResponse = check self.googleContactClient->get(pathWithQuery);
        var response = check handleResponseWithNull(httpResponse);
        var searchResponse = check response.cloneWithType(SearchResponse);
        PersonResponse[] persons = [];
        int i = persons.length();
        foreach var result in searchResponse.results {
            var personResult = result.person;
            if(personResult is json) {
                persons[i] = check personResult.cloneWithType(PersonResponse);
                i = i + 1;
            }
        }
        return persons;
    }

    # Update contact photo for a contact.
    # 
    # + resourceName - Contact resource name
    # + imagePath - Path to image from root directory
    # + return - Nil on success, else an 'error'
    @display {label: "Update Contact Photo"}
    isolated remote function updateContactPhoto(@display {label: "Resource Name"} string resourceName,
                                                @display {label: "Image Path"} string imagePath) returns error? {
        string path = SLASH + resourceName + COLON + UPDATE_PHOTO_PATH;
        http:Request request = new;
        string encodedString = check convertImageToBase64String(imagePath);
        json updatePayload = {"photoBytes": encodedString};
        request.setJsonPayload(updatePayload);
        http:Response uploadResponse = check self.googleContactClient->patch(path, request);
        return handleUploadPhotoResponse(uploadResponse);
    }

    # Delete a contact photo.
    # 
    # + resourceName - Contact resource name
    # + return - Nil on success, else an 'error'
    @display {label: "Delete Contact Photo"}
    isolated remote function deleteContactPhoto(@display {label: "Resource Name"} string resourceName) returns error? {
        string path = SLASH + resourceName + COLON + DELETE_PHOTO_PATH;
        http:Response deleteResponse = check self.googleContactClient->delete(path);
        return handleDeleteResponse(deleteResponse);
    }

    # Get Batch contacts.
    # 
    # + resourceNames - String array of contact resource names
    # + personFields - Restrict which fields on the person are returned
    # + return - `PersonResponse[]` will have information specified by `Person Fields` on success, else an `error`
    @display {label: "Get Batch Contacts"}   
    isolated remote function getBatchContacts(@display {label: "Resource Names"} string[] resourceNames, 
                                              @display {label: "Person Fields"} FieldMask[] personFields) returns 
                                              @tainted @display {label: "PersonResponse Array"} PersonResponse[]|error {
        string path = SLASH + BATCH_CONTACT_PATH;
        string pathWithResources = prepareResourceString(path, resourceNames);
        string pathWithPersonFields = prepareUrlWithPersonFields(pathWithResources + AMBERSAND, personFields);
        http:Response httpResponse = check self.googleContactClient->get(pathWithPersonFields);
        var response = check handleResponse(httpResponse);
        var batchResponse = check response.cloneWithType(BatchGetResponse);
        PersonResponse[] persons = [];
        int i = persons.length();
        foreach var result in batchResponse.responses {
            var personResult = result.person;
            if(personResult is json) {
                persons[i] = check personResult.cloneWithType(PersonResponse);
                i = i + 1;
            }
        }
        return persons;
    }

    # Update a contact.
    # 
    # + resourceName - Contact resource name
    # + person - Person/Contact details
    # + updatePersonFields - Restrict which fields on the person are returned
    # + personFields - Restrict which fields on the person are returned
    # + return - `PersonResponse` will have information specified by `Person Fields` on success else an `error`
    @display {label: "Update Contact"}  
    isolated remote function updateContact(@display {label: "Resource Name"} string resourceName, 
                                           @display {label: "Contact Details"} Person person, 
                                           @display {label: "Person Fields To Update"} FieldMask[] updatePersonFields,
                                           @display {label: "Person Fields To Return"} FieldMask[]? personFields = ()) 
                                           returns @display {label: "PersonResponse"} PersonResponse|error {
        string getPath = SLASH + resourceName + QUESTION_MARK;
        string getPathWithPersonFields = prepareUrlWithPersonFields(getPath, personFields);
        http:Response httpResponse = check self.googleContactClient->get(getPathWithPersonFields);
        json getResponse = check handleResponse(httpResponse);
        PersonResponse getContact = check getResponse.cloneWithType(PersonResponse);
        string path = SLASH + resourceName + ":updateContact" + QUESTION_MARK;
        string pathWithUpdatePersonFields = prepareUrlWithUpdatePersonFields(path, updatePersonFields);
        string pathWithFields = pathWithUpdatePersonFields + AMBERSAND;
        http:Request request = new;
        string pathWithPersonFields = prepareUrlWithPersonFields(pathWithFields, personFields);
        _ = prepareUpdate(person, getContact);
        json payload = check getContact.cloneWithType(json);
        request.setJsonPayload(payload);
        http:Response updateResponse = check self.googleContactClient->patch(pathWithPersonFields, request);
        json response = check handleResponse(updateResponse);
        return check response.cloneWithType(PersonResponse);
    }

    # Delete a Contact.
    # 
    # + resourceName - Contact resource name
    # + return - Nil on success, else an `error`
    @display {label: "Delete Contact"}
    isolated remote function deleteContact(@display {label: "Resource Name"} string resourceName) returns error? {
        string path = SLASH + resourceName + COLON + DELETE_CONTACT_PATH;
        http:Response deleteResponse = check self.googleContactClient->delete(path);
        return handleDeleteResponse(deleteResponse);
    }

    // Only Authenticated user's contacts can be obtained
    # Get Peoples
    # 
    # + personFields - Restrict which fields on the person are returned
    # + options - Record that contains options
    # + return - `stream<PersonResponse>` will have information specified by `Person Fields` on success or else an `error`
    @display {label: "List Contacts"}
    isolated remote function listContacts(@display {label: "Person Fields"} FieldMask[] personFields, 
                                          @display {label: "List options"} ContactListOptions? options = ()) 
                                          returns @display {label: "Stream of PersonResponses"} 
                                          stream<PersonResponse>|error {
        string path = SLASH + LIST_PEOPLE_PATH;
        string pathWithPersonFields = prepareUrlWithPersonFields(path, personFields);
        PersonResponse[] persons = [];
        return getContactsStream(self.googleContactClient, persons, pathWithPersonFields, options);
    }

    # Create a `ContactGroup`.
    # 
    # + contactGroupName - Name of the `ContactGroup` to be created
    # + return - `ContactGroup` on success else an `error`
    @display {label: "Create a Contact Group"}
    isolated remote function createContactGroup(@display {label: "Resource Name"} string contactGroupName) returns 
                                                @display {label: "Contact Group"} ContactGroup|error {
        string path = SLASH + CONTACT_GROUP_PATH;
        http:Request request = new;
        json createContactJsonPayload = {
            "contactGroup": {"name": contactGroupName},
            "readGroupFields": ""
        };
        request.setJsonPayload(createContactJsonPayload);
        http:Response httpResponse = check self.googleContactClient->post(path, request);
        var response = check handleResponse(httpResponse);
        return check response.cloneWithType(ContactGroup);
    }

    # Get Batch contact groups.
    # 
    # + resourceNames - An array of strings with names of `Contact Groups`
    # + return - `ContactGroup[]` on success else an `error`
    @display {label: "Get Batch Contact Groups"}   
    isolated remote function getBatchContactGroup(@display {label: "Resource Names"} string[] resourceNames) returns 
                                                @display {label: "Contact Group Array"} ContactGroup[]|error {
        string path = SLASH + CONTACT_GROUP_PATH + BATCH_CONTACT_GROUP_PATH;
        string pathWithResources = prepareResourceString(path, resourceNames);
        http:Response httpResponse = check self.googleContactClient->get(pathWithResources);
        var response = check handleResponse(httpResponse);
        var batchResponse = check response.cloneWithType(ContactGroupBatch);
        ContactGroup[] contactGroups = [];
        int i = contactGroups.length();
        foreach var result in batchResponse.responses {
            var contactGroupResult = result.contactGroup;
            if(contactGroupResult is json) {
                contactGroups[i] = check contactGroupResult.cloneWithType(ContactGroup);
                i = i + 1;
            }
        }
        return contactGroups;
    }

    # Fetch `ContactGroups` of authenticated user.
    # 
    # + return - `ContactGroup[]` on success else an `error`
    @display {label: "List Contact Groups"}
    isolated remote function listContactGroup() returns @display {label: "Contact Group Array"} ContactGroup[]|error {
        string path = SLASH + CONTACT_GROUP_PATH;
        http:Response httpResponse = check self.googleContactClient->get(path);
        var response = check handleResponse(httpResponse);
        ContactGroupList contactGroupList = check response.cloneWithType(ContactGroupList);
        ContactGroup[] contactGroupArray = contactGroupList.contactGroups;
        return contactGroupArray;
    }

    # Fetch a `ContactGroup`.
    # 
    # + resourceName - Name of the `ContactGroup` to be created
    # + maxMembers - maximum number of members returned in contact group
    # + return - `ContactGroup` on success else an `error`
    @display {label: "Get Contact Group"}
    isolated remote function getContactGroup(@display {label: "Resource Name"} string resourceName,
                                             @display {label: "Maximum Members"} int maxMembers) returns 
                                             @display {label: "Contact Group"} ContactGroup|error {
        string path = SLASH + resourceName;
        _ = prepareUrlWithStringParameter(path, maxMembers.toString());
        http:Response httpResponse = check self.googleContactClient->get(path);
        var response = check handleResponse(httpResponse);
        return response.cloneWithType(ContactGroup);
    }

    # Update a `ContactGroup`.
    # 
    # + resourceName - Name of the `ContactGroup` to be created
    # + updateName - Name to be updated
    # + return - `ContactGroup` on success else an `error`
    @display {label: "Update Contact Group"}
    isolated remote function updateContactGroup(@display {label: "Resource Name"} string resourceName,
                                                @display {label: "New Name"} string updateName) returns                          
                                                @display {label: "Contact Group"} ContactGroup|error {
        string path = SLASH + resourceName;
        http:Request request = new;
        string getpath = SLASH + resourceName;
        http:Response gethttpResponse = check self.googleContactClient->get(getpath);
        var getResponse = check handleResponse(gethttpResponse);
        ContactGroup getContactGroup = check getResponse.cloneWithType(ContactGroup);
        getContactGroup.name = updateName;
        json payload = check getContactGroup.cloneWithType(json);
        json newpayload = {"contactGroup": payload};
        request.setJsonPayload(newpayload);
        http:Response httpResponse = check self.googleContactClient->put(path, request);
        json response = check handleResponse(httpResponse);
        return check response.cloneWithType(ContactGroup);
    }

    # Delete a Contact Group.
    # 
    # + resourceName - Contact Group resource name
    # + return - Nil on success, else an `error`
    @display {label: "Delete Contact Group"}
    isolated remote function deleteContactGroup(@display {label: "Resource Name"} string resourceName) returns error? {
        string path = SLASH + resourceName;
        http:Response deleteResponse = check self.googleContactClient->delete(path);
        return handleDeleteResponse(deleteResponse);
    }

    # Modify a contacts in Contact Group.
    # 
    # + contactGroupResourceName - Contact Group resource name
    # + resourceNameToAdd - Contact resource name to add
    # + resourceNameToRemove - Contact resource name to remove
    # + return - Nil on success, else an `error`
    @display {label: "Modify Contacts In Contact Group"}
    isolated remote function modifyContactGroup(@display {label: "Resource Name"} string contactGroupResourceName, 
                                                @display {label: "Add (Resource Names)"} string[]? resourceNameToAdd = (), 
                                                @display {label: "Remove (Resource Names)"} string[]? resourceNameToRemove = ()) 
                                                returns error? {
        string path = SLASH + contactGroupResourceName + "/members:modify";
        http:Request request = new;
        json payload =  {
                            "resourceNamesToAdd": resourceNameToAdd,
                            "resourceNamesToRemove": resourceNameToRemove
                        };
        request.setJsonPayload(payload);
        http:Response response = check self.googleContactClient->post(path, request);
        return handleModifyResponse(response);
    }    
}
